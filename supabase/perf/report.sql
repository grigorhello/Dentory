-- MS-150 · How long the app's calls take in the database for the load-test clinic (`make perf-report`): each call as
-- PostgREST runs it for Olivia Grant, Load test dental's admin (role authenticated, her JWT claims set, the answer
-- built as JSON with the API's 1,000-row cap), 3 warm-up runs then `runs` timed ones, each in a transaction of its own;
-- the two writes the ticket names, Start procedure and Apply count, are rolled back after each run, so every run meets
-- the same clinic. Prints p50, p95 and the slowest run per call, in milliseconds.
--
-- Run after `make db-reset seed-load` (seed-demo may be there too): `make perf-report`, or `make perf-report
-- PERF_RUNS=100`. Server time only: the phone's network, the API gateway and PostgREST come on top
-- (docs/runbooks/performance.md). Local stack only.

\set ON_ERROR_STOP on
\if :{?runs}
\else
  \set runs 30
\endif

do $$
begin
  if not exists (select 1 from public.clinics where id = '10ad0000-0000-4000-8000-000000000001') then
    raise exception 'No load-test clinic here. Run make db-reset seed-load first.';
  end if;
end;
$$;

-- What is measured: each call's name, the screen that makes it and the SQL, with the clinic's ids filled in.
create temp table perf_calls (
  position serial primary key,
  name text not null,
  screen text not null,
  sql text not null,
  rolled_back boolean not null default false
);
create temp table perf_samples (name text not null, ms double precision not null);

do $$
declare
  c constant uuid := '10ad0000-0000-4000-8000-000000000001';
  -- Nitrile gloves M: in every procedure, so the longest history.
  v_gloves constant uuid := '10ad0000-0000-4000-8000-000200000351';
  v_template uuid;
  v_template_name text;
  v_items jsonb;
  v_event uuid;
  v_after uuid;
  v_counts jsonb;
  -- How PostgREST wraps a set-returning function or a table read (with the app's own limit, else the API's), and a
  -- function that returns one value.
  v_rows constant text := 'select coalesce(json_agg(t), ''[]'')::text from (%s limit 1000) t';
  v_limited constant text := 'select coalesce(json_agg(t), ''[]'')::text from (%s) t';
  v_value constant text := 'select (%s)::text';
begin
  -- The template with the most supplies, as Adjust, then start sends it: every supply at its default, none taken new.
  select t.id, t.name into v_template, v_template_name
  from public.procedure_templates t
  where t.clinic_id = c and t.archived_at is null
  order by (select count(*) from public.procedure_template_items i where i.template_id = t.id) desc, t.id
  limit 1;
  select jsonb_agg(jsonb_build_object('product_id', i.product_id, 'qty', i.default_qty) order by i.position)
  into v_items
  from public.procedure_template_items i
  where i.template_id = v_template;
  -- The latest procedure, and the 50th entry of History's first page for its second page.
  select e.id into v_event from public.procedure_events e where e.clinic_id = c order by e.started_at desc, e.id desc
  limit 1;
  -- 50 corrections of one to three units, in list order, as Count stock sends them.
  select jsonb_agg(jsonb_build_object('product_id', s.product_id, 'counted', greatest(s.unopened + 1 + (n % 3), 0))
    order by s.product_id)
  into v_counts
  from (
    select s.product_id, s.unopened, row_number() over (order by s.product_id) as n
    from public.product_stock s
    join public.products p on p.id = s.product_id
    where s.clinic_id = c and p.archived_at is null
    order by s.product_id
    limit 50
  ) s;

  insert into perf_calls (name, screen, sql) values
    ('clinic_attention', 'Home', format(v_rows, format(
      'select * from public.clinic_attention where clinic_id = %L', c))),
    ('procedure_events (latest)', 'Home', format(v_limited, format(
      'select e.id, e.name, e.started_at, e.started_by, coalesce((select json_agg(x) from (select count(*) as count '
        || 'from public.procedure_event_items i where i.event_id = e.id) x), ''[]'') as procedure_event_items '
        || 'from public.procedure_events e where e.clinic_id = %L and e.cancelled_at is null '
        || 'order by e.started_at desc limit 1', c))),
    ('memberships (starter)', 'Home', format(v_limited, format(
      'select m.full_name from public.memberships m where m.clinic_id = %L and m.user_id = %L limit 1',
      c, '10ad0000-0000-4000-8000-000100000002'))),
    ('alerts_unseen', 'Home', format(v_value, format('public.alerts_unseen(%L)', c))),
    ('inventory_list', 'Inventory', format(v_rows, format('select * from public.inventory_list(%L)', c))),
    ('product_detail', 'Product detail', format(v_value, format('public.product_detail(%L)', v_gloves))),
    ('activity_history (product)', 'Product history', format(v_rows, format(
      'select * from public.activity_history(%L, null, %L, null, 50)', c, v_gloves))),
    ('procedure_templates_list', 'Procedures', format(v_rows, format(
      'select * from public.procedure_templates_list(%L)', c))),
    ('procedure_history', 'Procedures', format(v_rows, format(
      'select * from public.procedure_history(%L, null, 30)', c))),
    ('procedure_template_detail', 'Adjust, then start', format(v_value, format(
      'public.procedure_template_detail(%L)', v_template))),
    ('procedure_event_detail', 'Procedure', format(v_value, format('public.procedure_event_detail(%L)', v_event))),
    ('to_buy_list', 'To buy', format(v_rows, format('select * from public.to_buy_list(%L)', c))),
    ('expiring_batches', 'Expiring soon', format(v_value, format('public.expiring_batches(%L)', c))),
    ('activity_alerts', 'Activity, Alerts', format(v_value, format('public.activity_alerts(%L)', c))),
    ('activity_history', 'Activity, History', format(v_rows, format(
      'select * from public.activity_history(%L, null, null, null, 50)', c))),
    ('activity_history (page 10)', 'Activity, History', 'select null'),
    ('receive_overview', 'Receive delivery', format(v_value, format('public.receive_overview(%L)', c))),
    ('receive_products', 'Receive manually', format(v_rows, format('select * from public.receive_products(%L)', c))),
    ('team_members', 'Team', format(v_rows, format('select * from public.team_members(%L)', c))),
    ('inventory_value', 'Inventory value', format(v_value, format('public.inventory_value(%L)', c)));

  -- History's tenth page starts after the 450th entry, which only the function itself can name.
  perform set_config('request.jwt.claims',
    json_build_object('sub', '10ad0000-0000-4000-8000-000100000001', 'role', 'authenticated')::text, true);
  select h.id into v_after from public.activity_history(c, null, null, null, 100) h offset 99 limit 1;
  for i in 1..3 loop
    select h.id into v_after from public.activity_history(c, null, null, v_after, 100) h offset 99 limit 1;
  end loop;
  select h.id into v_after from public.activity_history(c, null, null, v_after, 50) h offset 49 limit 1;
  update perf_calls set sql = format(v_rows, format(
    'select * from public.activity_history(%L, null, null, %L, 50)', c, v_after))
  where name = 'activity_history (page 10)';

  insert into perf_calls (name, screen, sql, rolled_back) values
    ('stock_procedure_start', format('Start procedure (%s, %s supplies)', v_template_name, jsonb_array_length(v_items)),
      format(v_value, format('public.stock_procedure_start(%L, %L, %L, %L::jsonb, ''{}'', gen_random_uuid())',
        c, v_template, v_template_name, v_items)), true),
    ('stock_count_apply', 'Apply count (50 corrections)',
      format(v_value, format('public.stock_count_apply(%L, %L::jsonb, gen_random_uuid())', c, v_counts)), true);
end;
$$;

-- Runs every call, each run in a transaction of its own as the API does; the writes roll back.
create procedure pg_temp.measure(p_runs int)
language plpgsql
as $$
declare
  v_call record;
  v_samples double precision[];
  v_started timestamptz;
  v_claims constant text :=
    json_build_object('sub', '10ad0000-0000-4000-8000-000100000001', 'role', 'authenticated')::text;
begin
  for v_call in select * from perf_calls order by position loop
    v_samples := '{}';
    for v_run in 1 .. p_runs + 3 loop
      perform set_config('request.jwt.claims', v_claims, true);
      perform set_config('role', 'authenticated', true);
      v_started := clock_timestamp();
      execute v_call.sql;
      if v_run > 3 then
        v_samples := v_samples || extract(epoch from clock_timestamp() - v_started)::double precision * 1000;
      end if;
      if v_call.rolled_back then rollback; else commit; end if;
    end loop;
    insert into perf_samples select v_call.name, unnest(v_samples);
    commit;
  end loop;
end;
$$;

call pg_temp.measure(:runs);

\echo
\echo 'Load test dental, as its admin: milliseconds in the database per call'
select c.screen as "Screen", c.name as "Call", count(*) as "Runs",
  round(percentile_cont(0.5) within group (order by s.ms)::numeric, 1) as "p50",
  round(percentile_cont(0.95) within group (order by s.ms)::numeric, 1) as "p95",
  round(max(s.ms)::numeric, 1) as "Slowest"
from perf_calls c
join perf_samples s on s.name = c.name
group by c.position, c.screen, c.name
order by c.position;
