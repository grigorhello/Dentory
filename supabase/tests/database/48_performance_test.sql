-- MS-150 · The performance migration (20261021140000_performance.sql) changes how fast, not what: the indexes are
-- there; every read policy lets each caller read the rows is_member or is_admin let them read before, and no read
-- policy asks either of each row again; product_stock answers as MS-104's view did; every stock change takes its
-- clinic's lock, and only that one.
begin;
select plan(38);

-- Fixtures: two clinics with rows in every table the policies guard, made through the engine's functions where they
-- hold stock; their admins, a staff member, an invited and a revoked account in the first, and an account in neither.
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-0000000048a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-0000000048a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-0000000048b1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'lee@dentory.test'),
  ('00000000-0000-4000-8000-0000000048d1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'priya@dentory.test'),
  ('00000000-0000-4000-8000-0000000048e1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tom@dentory.test'),
  ('00000000-0000-4000-8000-0000000048f1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ana@dentory.test'),
  ('00000000-0000-4000-8000-0000000048a6', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'nora@dentory.test'),
  ('00000000-0000-4000-8000-0000000048a7', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'omar@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone) values
  ('00000000-0000-4000-8000-0000000048c1', 'Smile Dental', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-0000000048c2', 'Other Dental', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-0000000048c3', 'Lock Dental 3', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-0000000048c4', 'Lock Dental 4', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-0000000048c5', 'Lock Dental 5', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-0000000048c6', 'Lock Dental 6', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-0000000048c7', 'Lock Dental 7', 'CA', 'CAD', 'America/Toronto');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-0000000048c1', '00000000-0000-4000-8000-0000000048a1', 'sarah@dentory.test', 'Sarah Mitchell',
   'admin', 'active'),
  ('00000000-0000-4000-8000-0000000048c1', '00000000-0000-4000-8000-0000000048a2', 'michael@dentory.test',
   'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-0000000048c1', '00000000-0000-4000-8000-0000000048d1', 'priya@dentory.test', 'Priya Shah',
   'staff', 'invited'),
  ('00000000-0000-4000-8000-0000000048c1', '00000000-0000-4000-8000-0000000048e1', 'tom@dentory.test', 'Tom Baker',
   'admin', 'revoked'),
  ('00000000-0000-4000-8000-0000000048c2', '00000000-0000-4000-8000-0000000048b1', 'lee@dentory.test', 'Lee Park',
   'admin', 'active'),
  ('00000000-0000-4000-8000-0000000048c6', '00000000-0000-4000-8000-0000000048a6', 'nora@dentory.test', 'Nora Quinn',
   'admin', 'active'),
  ('00000000-0000-4000-8000-0000000048c7', '00000000-0000-4000-8000-0000000048a7', 'omar@dentory.test', 'Omar Haddad',
   'admin', 'active');
insert into public.categories (id, clinic_id, name) values
  ('00000000-0000-4000-8000-000000004821', '00000000-0000-4000-8000-0000000048c1', 'Restorative'),
  ('00000000-0000-4000-8000-000000004822', '00000000-0000-4000-8000-0000000048c2', 'Hygiene');
insert into public.products (id, clinic_id, category_id, name, unit, tracking, minimum, target) values
  ('00000000-0000-4000-8000-000000004801', '00000000-0000-4000-8000-0000000048c1',
   '00000000-0000-4000-8000-000000004821', 'Nitrile gloves M', 'boxes', 'countable', 5, 20),
  ('00000000-0000-4000-8000-000000004802', '00000000-0000-4000-8000-0000000048c1',
   '00000000-0000-4000-8000-000000004821', 'Bonding agent', 'bottles', 'multi_use', 0, 2),
  ('00000000-0000-4000-8000-000000004803', '00000000-0000-4000-8000-0000000048c1', null, 'Suction tips', 'bags',
   'countable', 0, 0),
  ('00000000-0000-4000-8000-000000004804', '00000000-0000-4000-8000-0000000048c1', null, 'Gutta percha F2', 'packs',
   'countable', 2, 6),
  ('00000000-0000-4000-8000-000000004805', '00000000-0000-4000-8000-0000000048c2',
   '00000000-0000-4000-8000-000000004822', 'Fluoride varnish', 'tubes', 'multi_use', 0, 1),
  ('00000000-0000-4000-8000-000000004806', '00000000-0000-4000-8000-0000000048c2',
   '00000000-0000-4000-8000-000000004822', 'Prophy paste', 'cups', 'countable', 10, 30),
  ('00000000-0000-4000-8000-000000004807', '00000000-0000-4000-8000-0000000048c4', null, 'Cotton rolls', 'boxes',
   'countable', 0, 0),
  ('00000000-0000-4000-8000-000000004808', '00000000-0000-4000-8000-0000000048c5', null, 'Bibs', 'packs',
   'countable', 0, 0);
insert into public.procedure_templates (id, clinic_id, name) values
  ('00000000-0000-4000-8000-000000004811', '00000000-0000-4000-8000-0000000048c1', 'Filling'),
  ('00000000-0000-4000-8000-000000004812', '00000000-0000-4000-8000-0000000048c2', 'Cleaning');
insert into public.procedure_template_items (clinic_id, template_id, product_id, default_qty, position) values
  ('00000000-0000-4000-8000-0000000048c1', '00000000-0000-4000-8000-000000004811',
   '00000000-0000-4000-8000-000000004801', 2, 1),
  ('00000000-0000-4000-8000-0000000048c1', '00000000-0000-4000-8000-000000004811',
   '00000000-0000-4000-8000-000000004804', 7, 2),
  ('00000000-0000-4000-8000-0000000048c2', '00000000-0000-4000-8000-000000004812',
   '00000000-0000-4000-8000-000000004806', 1, 1);
insert into public.invoices (id, clinic_id, source, status, created_by) values
  ('00000000-0000-4000-8000-000000004831', '00000000-0000-4000-8000-0000000048c1', 'manual', 'ready',
   '00000000-0000-4000-8000-0000000048a1'),
  ('00000000-0000-4000-8000-000000004832', '00000000-0000-4000-8000-0000000048c2', 'manual', 'ready',
   '00000000-0000-4000-8000-0000000048b1');
insert into public.invoice_lines (clinic_id, invoice_id, n, raw, read_state) values
  ('00000000-0000-4000-8000-0000000048c1', '00000000-0000-4000-8000-000000004831', 1, 'NITRILE GLOVES M',
   'needs_review'),
  ('00000000-0000-4000-8000-0000000048c2', '00000000-0000-4000-8000-000000004832', 1, 'PROPHY PASTE', 'needs_review');
insert into public.export_jobs (clinic_id, requested_by) values
  ('00000000-0000-4000-8000-0000000048c1', '00000000-0000-4000-8000-0000000048a1'),
  ('00000000-0000-4000-8000-0000000048c2', '00000000-0000-4000-8000-0000000048b1');
insert into public.clinic_billing (clinic_id) values
  ('00000000-0000-4000-8000-0000000048c1'), ('00000000-0000-4000-8000-0000000048c2');
insert into public.billing_invoices (clinic_id, stripe_invoice_id, issued_at, amount_cents, currency, status) values
  ('00000000-0000-4000-8000-0000000048c1', 'in_48c1', now(), 4900, 'cad', 'paid'),
  ('00000000-0000-4000-8000-0000000048c2', 'in_48c2', now(), 4900, 'cad', 'paid');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

-- Stock through the engine: two dated deliveries of gloves and an undated box, bonding agent bottles of which one is
-- finished, a gutta percha procedure that takes more than there is, and the second clinic's own.
select pg_temp.act_as('00000000-0000-4000-8000-0000000048a1');
select public.stock_receive('00000000-0000-4000-8000-0000000048c1', jsonb_build_array(
  jsonb_build_object('product_id', '00000000-0000-4000-8000-000000004801', 'qty', 20, 'lot', 'A112',
    'expiry_month', (date_trunc('month', now()) + interval '2 months')::date),
  jsonb_build_object('product_id', '00000000-0000-4000-8000-000000004801', 'qty', 34, 'lot', 'B441',
    'expiry_month', (date_trunc('month', now()) + interval '16 months')::date),
  jsonb_build_object('product_id', '00000000-0000-4000-8000-000000004801', 'qty', 3),
  jsonb_build_object('product_id', '00000000-0000-4000-8000-000000004802', 'qty', 3),
  jsonb_build_object('product_id', '00000000-0000-4000-8000-000000004804', 'qty', 4,
    'expiry_month', (date_trunc('month', now()) + interval '20 months')::date)
), gen_random_uuid());
select public.bottle_open('00000000-0000-4000-8000-000000004802', gen_random_uuid());
select public.bottle_open('00000000-0000-4000-8000-000000004802', gen_random_uuid());
select public.bottle_finish(
  (select o.id from public.open_items o where o.product_id = '00000000-0000-4000-8000-000000004802'
   order by o.opened_at, o.id limit 1),
  gen_random_uuid()
);
select pg_temp.act_as('00000000-0000-4000-8000-0000000048a2');
select public.stock_procedure_start('00000000-0000-4000-8000-0000000048c1', '00000000-0000-4000-8000-000000004811',
  'Filling', jsonb_build_array(
    jsonb_build_object('product_id', '00000000-0000-4000-8000-000000004801', 'qty', 2),
    jsonb_build_object('product_id', '00000000-0000-4000-8000-000000004804', 'qty', 7)
  ), array['00000000-0000-4000-8000-000000004802']::uuid[], gen_random_uuid());
select pg_temp.act_as('00000000-0000-4000-8000-0000000048b1');
select public.stock_receive('00000000-0000-4000-8000-0000000048c2', jsonb_build_array(
  jsonb_build_object('product_id', '00000000-0000-4000-8000-000000004805', 'qty', 2),
  jsonb_build_object('product_id', '00000000-0000-4000-8000-000000004806', 'qty', 5, 'lot', 'P9',
    'expiry_month', (date_trunc('month', now()) + interval '1 month')::date)
), gen_random_uuid());
select public.bottle_open('00000000-0000-4000-8000-000000004805', gen_random_uuid());
select public.stock_procedure_start('00000000-0000-4000-8000-0000000048c2', '00000000-0000-4000-8000-000000004812',
  'Cleaning', jsonb_build_array(jsonb_build_object('product_id', '00000000-0000-4000-8000-000000004806', 'qty', 1)),
  '{}', gen_random_uuid());
reset role;

-- Indexes -----------------------------------------------------------------------------------------------------------
select has_index('public', 'alerts', 'alerts_product_open_idx', array['product_id', 'kind'],
  'refresh_product finds a product''s open alerts by kind');
select has_index('public', 'to_buy_items', 'to_buy_items_product_idx', array['product_id', 'status'],
  'and its To buy line, ordered or not');
select has_index('public', 'transactions', 'transactions_ref_idx', array['ref_id'],
  'editing or cancelling a procedure reads back what it took');
select has_index('public', 'transactions', 'transactions_open_item_idx', array['open_item_id'],
  'putting a bottle back finds the ledger row that opened it');
select has_index('public', 'batches', 'batches_clinic_idx', array['clinic_id'], 'a clinic''s batches are read by clinic');

-- Read policies -----------------------------------------------------------------------------------------------------
select is(
  array(
    select p.tablename || '.' || p.policyname
    from pg_catalog.pg_policies p
    where p.schemaname = 'public' and p.cmd = 'SELECT' and p.qual ~ '(^|[^a-z_])(is_member|is_admin)\('
    order by 1
  ),
  array[]::text[],
  'no read policy asks is_member or is_admin of each row; the caller''s clinics are read once per query'
);
select ok(
  has_function_privilege('authenticated', 'public.current_admin_clinic_ids()', 'execute')
    and not has_function_privilege('anon', 'public.current_admin_clinic_ids()', 'execute'),
  'the admin policies'' list of clinics is the signed-in caller''s alone'
);

-- The rows of a table a caller reads through its policy, by key; and the rows MS-105's rule let them read: the same
-- query as postgres, which row level security does not filter, asking is_member or is_admin of each row.
create function pg_temp.seen(p_user uuid, p_table text, p_key text) returns text language plpgsql as $$
declare
  v_rows text;
begin
  perform pg_temp.act_as(p_user);
  execute format('select coalesce(string_agg(%1$I::text, '','' order by %1$I::text), '''') from public.%2$I',
    p_key, p_table) into v_rows;
  reset role;
  return v_rows;
end;
$$;
create function pg_temp.allowed(p_user uuid, p_table text, p_key text, p_rule text) returns text language plpgsql as $$
declare
  v_rows text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute format(
    'select coalesce(string_agg(%1$I::text, '','' order by %1$I::text), '''') from public.%2$I where public.%3$I(%4$I)',
    p_key, p_table, p_rule, case p_table when 'clinics' then 'id' else 'clinic_id' end
  ) into v_rows;
  return v_rows;
end;
$$;
create temp table callers (n integer primary key, user_id uuid not null);
insert into callers values
  (1, '00000000-0000-4000-8000-0000000048a1'), (2, '00000000-0000-4000-8000-0000000048a2'),
  (3, '00000000-0000-4000-8000-0000000048b1'), (4, '00000000-0000-4000-8000-0000000048d1'),
  (5, '00000000-0000-4000-8000-0000000048e1'), (6, '00000000-0000-4000-8000-0000000048f1');
create temp table guarded (name text primary key, key text not null, rule text not null);
insert into guarded values
  ('clinics', 'id', 'is_member'), ('memberships', 'id', 'is_member'), ('categories', 'id', 'is_member'),
  ('products', 'id', 'is_member'), ('batches', 'id', 'is_member'), ('open_items', 'id', 'is_member'),
  ('transactions', 'id', 'is_member'), ('stock_actions', 'id', 'is_member'), ('procedure_templates', 'id', 'is_member'),
  ('procedure_template_items', 'id', 'is_member'), ('procedure_events', 'id', 'is_member'),
  ('procedure_event_items', 'id', 'is_member'), ('procedure_event_openings', 'id', 'is_member'),
  ('to_buy_items', 'id', 'is_member'), ('alerts', 'id', 'is_member'),
  ('invoices', 'id', 'is_admin'), ('invoice_lines', 'id', 'is_admin'), ('export_jobs', 'id', 'is_admin'),
  ('clinic_billing', 'clinic_id', 'is_admin'), ('billing_invoices', 'id', 'is_admin');

select is(
  array(
    select g.name from guarded g
    where pg_temp.allowed('00000000-0000-4000-8000-0000000048a1', g.name, g.key, g.rule) = ''
       or pg_temp.allowed('00000000-0000-4000-8000-0000000048b1', g.name, g.key, g.rule) = ''
    order by 1
  ),
  array[]::text[],
  'both clinics have rows in every table below, so no comparison is between two empty answers'
);
select is(
  array(select pg_temp.seen(c.user_id, g.name, g.key) from callers c order by c.n),
  array(select pg_temp.allowed(c.user_id, g.name, g.key, g.rule) from callers c order by c.n),
  format('%s: each caller reads the rows %s let them read before, no more and no fewer', g.name, g.rule)
)
from guarded g
order by g.name;

-- product_stock -----------------------------------------------------------------------------------------------------
-- MS-104's definition (20261016021500_schema.sql), the answer the rewritten view must give.
create temp table old_product_stock (sql text);
insert into old_product_stock values ($$
  select
    p.id as product_id,
    p.clinic_id,
    p.tracking,
    coalesce(b.unopened, 0)::numeric(12, 2) as unopened,
    coalesce(o.open_count, 0)::integer as open_count,
    (coalesce(b.unopened, 0) + case when p.tracking = 'multi_use' then coalesce(o.open_count, 0) else 0 end)
      ::numeric(12, 2) as quantity,
    greatest(coalesce(b.missing_expiry_qty, 0), 0)::numeric(12, 2) as missing_expiry_qty,
    b.soonest_expiry
  from public.products p
  left join (
    select
      product_id,
      sum(qty) as unopened,
      sum(qty) filter (where expiry_month is null) as missing_expiry_qty,
      min(expiry_month) filter (where qty > 0) as soonest_expiry
    from public.batches
    group by product_id
  ) b on b.product_id = p.id
  left join (
    select product_id, count(*) as open_count
    from public.open_items
    where finished_at is null
    group by product_id
  ) o on o.product_id = p.id
$$);
grant select on old_product_stock to authenticated;

select bag_eq('select * from public.product_stock', (select sql from old_product_stock),
  'product_stock answers as MS-104''s view did for every product: shortfall, open bottles, empty and undated');
select results_eq(
  $$select product_id::text, unopened, open_count, quantity, missing_expiry_qty from public.product_stock
    where product_id in ('00000000-0000-4000-8000-000000004801', '00000000-0000-4000-8000-000000004802',
                         '00000000-0000-4000-8000-000000004803', '00000000-0000-4000-8000-000000004804')
    order by product_id$$,
  $$values ('00000000-0000-4000-8000-000000004801', 55.00::numeric, 0, 55.00::numeric, 3.00::numeric),
           ('00000000-0000-4000-8000-000000004802', 0.00::numeric, 2, 2.00::numeric, 0.00::numeric),
           ('00000000-0000-4000-8000-000000004803', 0.00::numeric, 0, 0.00::numeric, 0.00::numeric),
           ('00000000-0000-4000-8000-000000004804', -3.00::numeric, 0, -3.00::numeric, 0.00::numeric)$$,
  'the fixtures cover what the view sums: dated, undated, opened, finished, nothing at all and short'
);
select pg_temp.act_as('00000000-0000-4000-8000-0000000048a2');
select bag_eq('select * from public.product_stock', (select sql from old_product_stock),
  'and as a member, through the same policies: only their clinic''s products');
reset role;

-- A clinic's lock ---------------------------------------------------------------------------------------------------
-- Whether this transaction holds engine.stock_lock's lock for a clinic.
create function pg_temp.holds_stock_lock(p_clinic_id uuid) returns boolean language sql as $$
  select exists (
    select 1 from pg_catalog.pg_locks l
    where l.locktype = 'advisory' and l.pid = pg_catalog.pg_backend_pid() and l.granted and l.objsubid = 2
      and l.classid::bigint = (hashtext('stock_lock')::bigint & 4294967295)
      and l.objid::bigint = (hashtext(p_clinic_id::text)::bigint & 4294967295)
  );
$$;

select is(
  array(
    select pg_temp.holds_stock_lock(c) from unnest(array[
      '00000000-0000-4000-8000-0000000048c3', '00000000-0000-4000-8000-0000000048c4',
      '00000000-0000-4000-8000-0000000048c5', '00000000-0000-4000-8000-0000000048c6',
      '00000000-0000-4000-8000-0000000048c7'
    ]::uuid[]) c
  ),
  array[false, false, false, false, false],
  'no lock is held for the five clinics below before their calls'
);
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-4000-8000-0000000048a1', 'role', 'authenticated')::text, true);
select engine.begin_action('00000000-0000-4000-8000-0000000048c3', gen_random_uuid(), 'adjust');
select ok(pg_temp.holds_stock_lock('00000000-0000-4000-8000-0000000048c3'),
  'begin_action, every multi-product change''s first step, takes its clinic''s lock');
select engine.lock_product('00000000-0000-4000-8000-000000004807');
select ok(
  pg_temp.holds_stock_lock('00000000-0000-4000-8000-0000000048c4')
    and not pg_temp.holds_stock_lock('00000000-0000-4000-8000-0000000048c5'),
  'lock_product takes the lock of its product''s clinic, and no other clinic''s'
);
select engine.lock_product_row('00000000-0000-4000-8000-000000004808');
select ok(pg_temp.holds_stock_lock('00000000-0000-4000-8000-0000000048c5'),
  'lock_product_row, the single-product changes'' first step, takes it too');
select pg_temp.act_as('00000000-0000-4000-8000-0000000048a6');
select public.to_buy_mark_ordered('00000000-0000-4000-8000-0000000048c6', '{}');
reset role;
select ok(pg_temp.holds_stock_lock('00000000-0000-4000-8000-0000000048c6'),
  'Mark as ordered takes the same lock, though it runs as the caller');
select pg_temp.act_as('00000000-0000-4000-8000-0000000048a7');
select public.clinic_settings_save('00000000-0000-4000-8000-0000000048c7', 'Lock Dental 7', null, 'CA', 'CAD',
  'America/Vancouver', '{60,90}', false);
reset role;
select ok(pg_temp.holds_stock_lock('00000000-0000-4000-8000-0000000048c7'),
  'and so does a clinic setting that refreshes every product');

select * from finish();
rollback;
