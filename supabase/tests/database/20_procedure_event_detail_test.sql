-- MS-124 · procedure_event_detail, and editing and cancelling a procedure the way the history screen sends it.
begin;
select plan(24);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000000f31', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000000f32', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000000f33', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-000000000f41', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', '{90}'),
  ('00000000-0000-4000-8000-000000000f42', 'Other Dental', 'CA', 'CAD', 'America/Toronto', '{90}');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f31', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f32', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000000f42', '00000000-0000-4000-8000-000000000f33', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target) values
  ('00000000-0000-4000-8000-000000000f61', '00000000-0000-4000-8000-000000000f41', 'Septocaine', 'cartridges', 'countable', 5, 60),
  ('00000000-0000-4000-8000-000000000f62', '00000000-0000-4000-8000-000000000f41', 'Gloves', 'boxes', 'countable', 2, 20),
  ('00000000-0000-4000-8000-000000000f63', '00000000-0000-4000-8000-000000000f41', 'Disinfectant', 'bottles', 'multi_use', 0, 4),
  ('00000000-0000-4000-8000-000000000f64', '00000000-0000-4000-8000-000000000f41', 'Sealer', 'kits', 'multi_use', 0, 2);
-- Septocaine in two batches, the one expiring sooner used first; Disinfectant 2 unopened and 1 open; Sealer 1 open.
insert into public.batches (id, clinic_id, product_id, expiry_month, qty) values
  ('00000000-0000-4000-8000-000000000f81', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f61',
   date_trunc('month', current_date + interval '5 months')::date, 10),
  ('00000000-0000-4000-8000-000000000f82', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f61',
   date_trunc('month', current_date + interval '10 months')::date, 50),
  ('00000000-0000-4000-8000-000000000f83', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f62',
   date_trunc('month', current_date + interval '10 months')::date, 20),
  ('00000000-0000-4000-8000-000000000f84', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f63',
   date_trunc('month', current_date + interval '10 months')::date, 2);
insert into public.open_items (clinic_id, product_id, opened_by, opened_at) values
  ('00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f63', '00000000-0000-4000-8000-000000000f31', now() - interval '3 days'),
  ('00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f64', '00000000-0000-4000-8000-000000000f31', now() - interval '3 days');
insert into public.procedure_templates (id, clinic_id, name) values
  ('00000000-0000-4000-8000-000000000f71', '00000000-0000-4000-8000-000000000f41', 'Root canal');
insert into public.procedure_template_items (clinic_id, template_id, product_id, default_qty, position) values
  ('00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f71', '00000000-0000-4000-8000-000000000f61', 2, 1),
  ('00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f71', '00000000-0000-4000-8000-000000000f62', 2, 2),
  ('00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f71', '00000000-0000-4000-8000-000000000f63', 0, 3),
  ('00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f71', '00000000-0000-4000-8000-000000000f64', 0, 4);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.items(p_event uuid) returns table (name text, tracking text, qty numeric, taken_new boolean)
language sql as $$
  select i ->> 'name', i ->> 'tracking', (i ->> 'qty')::numeric, (i ->> 'taken_new')::boolean
  from jsonb_array_elements(public.procedure_event_detail(p_event) -> 'items') i
$$;
-- A started procedure's id is its action's id.
create function pg_temp.event(p_key uuid) returns uuid language sql as $$
  select id from public.stock_actions where idempotency_key = p_key
$$;
create function pg_temp.stock(p_product uuid) returns table (quantity numeric, unopened numeric, open_count integer)
language sql as $$ select quantity, unopened, open_count from public.product_stock where product_id = p_product $$;

select ok(not has_function_privilege('anon', 'public.procedure_event_detail(uuid)', 'execute'), 'anon cannot read a procedure');

-- Michael performs the Root canal with Disinfectant taken new.
select pg_temp.act_as('00000000-0000-4000-8000-000000000f32');
select lives_ok($$
  select public.stock_procedure_start(
    '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f71', 'Root canal',
    '[{"product_id":"00000000-0000-4000-8000-000000000f61","qty":2},
      {"product_id":"00000000-0000-4000-8000-000000000f62","qty":2},
      {"product_id":"00000000-0000-4000-8000-000000000f63","qty":0},
      {"product_id":"00000000-0000-4000-8000-000000000f64","qty":0}]',
    array['00000000-0000-4000-8000-000000000f63']::uuid[], '00000000-0000-4000-8000-000000000fa1')
$$, 'Michael performs the Root canal');
select is(public.procedure_event_detail(pg_temp.event('00000000-0000-4000-8000-000000000fa1')) ->> 'started_by_name',
  'Michael Reyes', 'the detail names who performed it');
select results_eq(
  $$ select * from pg_temp.items(pg_temp.event('00000000-0000-4000-8000-000000000fa1')) $$,
  $$ values ('Septocaine', 'countable', 2::numeric, false), ('Gloves', 'countable', 2::numeric, false),
            ('Disinfectant', 'multi_use', 0::numeric, true), ('Sealer', 'multi_use', 0::numeric, false) $$,
  'its supplies come in the template''s order, the new bottle marked and the open one used at 0');
select is(public.procedure_event_detail(pg_temp.event('00000000-0000-4000-8000-000000000fa1')) -> 'cancelled_at',
  'null'::jsonb, 'it is not cancelled');

-- Acceptance: +1 on one item and −1 on another write exactly two transactions.
select lives_ok($$
  select public.stock_procedure_edit(pg_temp.event('00000000-0000-4000-8000-000000000fa1'),
    '[{"product_id":"00000000-0000-4000-8000-000000000f61","qty":3},
      {"product_id":"00000000-0000-4000-8000-000000000f62","qty":1},
      {"product_id":"00000000-0000-4000-8000-000000000f63","qty":0},
      {"product_id":"00000000-0000-4000-8000-000000000f64","qty":0}]',
    array['00000000-0000-4000-8000-000000000f63']::uuid[], '00000000-0000-4000-8000-000000000fa2')
$$, 'Michael edits the usage: one more Septocaine, one Gloves less');
select is(
  (select count(*) from public.transactions where action_id = (
    select id from public.stock_actions where idempotency_key = '00000000-0000-4000-8000-000000000fa2')),
  2::bigint, 'the edit writes exactly two transactions');
select results_eq(
  $$ select * from pg_temp.items(pg_temp.event('00000000-0000-4000-8000-000000000fa1')) $$,
  $$ values ('Septocaine', 'countable', 3::numeric, false), ('Gloves', 'countable', 1::numeric, false),
            ('Disinfectant', 'multi_use', 0::numeric, true), ('Sealer', 'multi_use', 0::numeric, false) $$,
  'the record follows, and the multi-use rows at 0 stay');
select results_eq($$ select * from pg_temp.stock('00000000-0000-4000-8000-000000000f62') $$,
  $$ values (19::numeric, 19::numeric, 0) $$, 'Gloves got one back');

-- A second edit: Gloves to 0, Sealer off the list, Disinfectant no longer taken new.
select lives_ok($$
  select public.stock_procedure_edit(pg_temp.event('00000000-0000-4000-8000-000000000fa1'),
    '[{"product_id":"00000000-0000-4000-8000-000000000f61","qty":3},
      {"product_id":"00000000-0000-4000-8000-000000000f62","qty":0},
      {"product_id":"00000000-0000-4000-8000-000000000f63","qty":0}]',
    '{}'::uuid[], '00000000-0000-4000-8000-000000000fa3')
$$, 'a second edit removes Gloves and Sealer and the new bottle');
select results_eq(
  $$ select * from pg_temp.items(pg_temp.event('00000000-0000-4000-8000-000000000fa1')) $$,
  $$ values ('Septocaine', 'countable', 3::numeric, false), ('Disinfectant', 'multi_use', 0::numeric, false) $$,
  'a countable at 0 and a product left off the list leave the record');
select results_eq($$ select * from pg_temp.stock('00000000-0000-4000-8000-000000000f63') $$,
  $$ values (3::numeric, 2::numeric, 1) $$, 'the bottle taken new is back unopened');
select results_eq($$ select * from pg_temp.stock('00000000-0000-4000-8000-000000000f62') $$,
  $$ values (20::numeric, 20::numeric, 0) $$, 'and Gloves are all back');

-- Acceptance: cancelling returns countables to their original batches.
select results_eq(
  $$ select qty from public.batches where product_id = '00000000-0000-4000-8000-000000000f61' order by expiry_month $$,
  $$ values (7::numeric), (50::numeric) $$, 'Septocaine came from the batch expiring sooner');
select throws_ok($$ select public.stock_procedure_cancel(pg_temp.event('00000000-0000-4000-8000-000000000fa1'), '  ',
  '00000000-0000-4000-8000-000000000fa4') $$, '22023', 'a note is required to cancel', 'a cancellation needs a note');
select lives_ok($$ select public.stock_procedure_cancel(pg_temp.event('00000000-0000-4000-8000-000000000fa1'),
  'Logged by mistake', '00000000-0000-4000-8000-000000000fa5') $$, 'Michael cancels it');
select results_eq(
  $$ select qty from public.batches where product_id = '00000000-0000-4000-8000-000000000f61' order by expiry_month $$,
  $$ values (10::numeric), (50::numeric) $$, 'the three Septocaine are back in their own batch');
select results_eq(
  $$ select d ->> 'cancel_note', d ->> 'cancelled_by_name', d -> 'cancelled_at' <> 'null'::jsonb
     from (select public.procedure_event_detail(pg_temp.event('00000000-0000-4000-8000-000000000fa1')) d) x $$,
  $$ values ('Logged by mistake', 'Michael Reyes', true) $$, 'the detail says who cancelled it and why');
select throws_ok($$
  select public.stock_procedure_edit(pg_temp.event('00000000-0000-4000-8000-000000000fa1'),
    '[{"product_id":"00000000-0000-4000-8000-000000000f61","qty":1}]', '{}'::uuid[], '00000000-0000-4000-8000-000000000fa6')
$$, '22023', 'the procedure was cancelled', 'a cancelled procedure cannot be edited');

-- Acceptance: cancelling reverses a bottle the procedure opened while it is still open.
select lives_ok($$
  select public.stock_procedure_start(
    '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f71', 'Root canal',
    '[{"product_id":"00000000-0000-4000-8000-000000000f63","qty":0}]',
    array['00000000-0000-4000-8000-000000000f63']::uuid[], '00000000-0000-4000-8000-000000000fa7')
$$, 'a second Root canal takes a new Disinfectant');
select results_eq($$ select * from pg_temp.stock('00000000-0000-4000-8000-000000000f63') $$,
  $$ values (3::numeric, 1::numeric, 2) $$, 'one bottle more is open');
select lives_ok($$ select public.stock_procedure_cancel(pg_temp.event('00000000-0000-4000-8000-000000000fa7'),
  'Patient cancelled', '00000000-0000-4000-8000-000000000fa8') $$, 'and it is cancelled');
select results_eq($$ select * from pg_temp.stock('00000000-0000-4000-8000-000000000f63') $$,
  $$ values (3::numeric, 2::numeric, 1) $$, 'the bottle it opened is back unopened');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000f33');
select is(public.procedure_event_detail(pg_temp.event('00000000-0000-4000-8000-000000000fa1')), null,
  'another clinic cannot read Smile Dental''s procedure');
reset role;

select * from finish();
rollback;
