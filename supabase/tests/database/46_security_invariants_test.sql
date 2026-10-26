-- MS-151 · What holds for every table, view and function the API reaches, now and after every later migration: row
-- level security on every table of the schemas PostgREST serves and of any other schema the API roles may use, views
-- that read as the caller, nothing for the anon key but the invitation lookup, security definer functions on an empty
-- search path, the internal schemas out of reach and private buckets. A table, view or function added without them
-- fails the database job (docs/security/security-review.md).
begin;
select plan(11);

-- The schemas PostgREST serves: supabase/config.toml, [api] schemas, and the hosted projects' Data API settings. A
-- schema added there is added here.
create temp table api_schemas (schema_name name primary key);
insert into api_schemas values ('public'), ('graphql_public');

-- Whether a role holds any right on a table, view or sequence, on the whole of it or on one of its columns. Each
-- check is asked of its own kind of relation only, which the planner does not promise of a where clause.
create function pg_temp.holds_any(p_role name, p_relation oid) returns boolean language sql as $$
  select case
    when c.relkind in ('r', 'p', 'v', 'm', 'f') then
      has_table_privilege(p_role, p_relation, 'select, insert, update, delete, truncate, references, trigger')
        or has_any_column_privilege(p_role, p_relation, 'select, insert, update, references')
    when c.relkind = 'S' then has_sequence_privilege(p_role, p_relation, 'usage, select, update')
    else false
  end
  from pg_catalog.pg_class c
  where c.oid = p_relation
$$;

-- This project's own schemas that the API roles may use. Postgres's (pg_catalog, information_schema, the temporary
-- ones), Supabase's (owned by supabase_admin: auth, storage, realtime, net, graphql, graphql_public, supabase_functions,
-- vault) and the extensions' are left out, since the platform keeps them; of those the Data API serves graphql_public
-- alone, checked with public above, and Storage's tables are checked below.
create function pg_temp.reachable(p_schema oid) returns boolean language sql as $$
  select (has_schema_privilege('anon', p_schema, 'usage') or has_schema_privilege('authenticated', p_schema, 'usage'))
    and n.nspname !~ '^pg_' and n.nspname <> 'information_schema'
    and pg_catalog.pg_get_userbyid(n.nspowner) <> 'supabase_admin'
    and not exists (select 1 from pg_catalog.pg_extension e where e.extnamespace = n.oid)
  from pg_catalog.pg_namespace n
  where n.oid = p_schema
$$;

-- Tables ----------------------------------------------------------------------------------------------------------
select is(
  array(
    select format('%I.%I', n.nspname, c.relname)
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where c.relkind in ('r', 'p') and n.nspname in (select a.schema_name from api_schemas a) and not c.relrowsecurity
    order by 1
  ),
  array[]::text[],
  'every table in a schema the API serves has row level security, whatever its grants'
);
select is(
  array(
    select format('%I.%I', n.nspname, c.relname)
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where c.relkind in ('r', 'p') and pg_temp.reachable(n.oid)
      and (pg_temp.holds_any('anon', c.oid) or pg_temp.holds_any('authenticated', c.oid))
      and not c.relrowsecurity
    order by 1
  ),
  array[]::text[],
  'every table the API roles hold a right on, in any schema they may use, has row level security'
);
select is(
  array(
    select format('%I.%I', n.nspname, c.relname)
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where c.relkind in ('v', 'm') and pg_temp.reachable(n.oid)
      and (pg_temp.holds_any('anon', c.oid) or pg_temp.holds_any('authenticated', c.oid))
      and not exists (select 1 from unnest(c.reloptions) o where o ~* '^security_invoker=(true|on|yes|1)$')
    order by 1
  ),
  array[]::text[],
  'every view the API roles can read runs as the caller, so its tables'' row level security applies'
);

-- The anon key ----------------------------------------------------------------------------------------------------
select is(
  array(
    select c.relname::text
    from pg_catalog.pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v', 'm', 'f', 'S')
      and pg_temp.holds_any('anon', c.oid)
    order by 1
  ),
  array[]::text[],
  'the anon key holds no right on any table, view or sequence in public'
);
select is(
  array(
    select p.proname || '(' || pg_catalog.pg_get_function_identity_arguments(p.oid) || ')'
    from pg_catalog.pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.prokind = 'f'
      and p.prorettype <> 'pg_catalog.trigger'::regtype
      and has_function_privilege('anon', p.oid, 'execute')
    order by 1
  ),
  array['invitation_lookup(p_token text)'],
  'the anon key executes one function in public: the invitation lookup the Join screen reads before sign-in'
);

-- Functions -------------------------------------------------------------------------------------------------------
select is(
  array(
    select n.nspname || '.' || p.proname || '(' || pg_catalog.pg_get_function_identity_arguments(p.oid) || ')'
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'engine') and p.prosecdef
      and not coalesce('search_path=""' = any (p.proconfig), false)
    order by 1
  ),
  array[]::text[],
  'every security definer function in public and engine runs on an empty search path'
);
select ok(
  not has_schema_privilege('anon', 'engine', 'usage') and not has_schema_privilege('authenticated', 'engine', 'usage'),
  'the API roles cannot reach the engine schema'
);
select ok(
  not has_schema_privilege('anon', 'vault', 'usage') and not has_schema_privilege('authenticated', 'vault', 'usage'),
  'nor Vault, which holds the service role key the cron jobs send'
);

-- Storage ---------------------------------------------------------------------------------------------------------
select ok(
  (select c.relrowsecurity from pg_catalog.pg_class c where c.oid = 'storage.objects'::regclass),
  'Storage objects have row level security'
);
select is(array(select b.id from storage.buckets b where b.public order by 1), array[]::text[], 'no bucket is public');
select is(
  array(
    select p.policyname::text
    from pg_catalog.pg_policies p
    where p.schemaname = 'storage' and p.roles && array['anon', 'public']::name[]
    order by 1
  ),
  array[]::text[],
  'no Storage policy lets a signed-out caller in'
);

select * from finish();
rollback;
