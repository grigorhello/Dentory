-- MS-121 · Count stock: three products from three filters counted in one go by staff, as the app sends them.
begin;
select plan(16);

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
-- Endo file kit is Low (1 of minimum 3), Nitrile gloves Healthy (14 dated), Bonding agent Expiring
-- (1 unopened due next month, 1 open), Suction tips Healthy and counted at its estimate.
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target, location) values
  ('00000000-0000-4000-8000-000000000f61', '00000000-0000-4000-8000-000000000f41', 'Endo file kit #15-40', 'kits', 'countable', 3, 5, 'Operatory 2 · Drawer B'),
  ('00000000-0000-4000-8000-000000000f62', '00000000-0000-4000-8000-000000000f41', 'Nitrile gloves M', 'boxes', 'countable', 6, 20, 'Sterilization · Shelf 2'),
  ('00000000-0000-4000-8000-000000000f63', '00000000-0000-4000-8000-000000000f41', 'Bonding agent', 'bottles', 'multi_use', 0, 2, 'Operatory 1 · Drawer C'),
  ('00000000-0000-4000-8000-000000000f64', '00000000-0000-4000-8000-000000000f41', 'Suction tips', 'bags', 'countable', 4, 12, 'Sterilization · Shelf 1');
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000000f71', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f61', date_trunc('month', current_date + interval '14 months')::date, 'EF1', 1),
  ('00000000-0000-4000-8000-000000000f72', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f62', date_trunc('month', current_date + interval '10 months')::date, 'NG4', 4),
  ('00000000-0000-4000-8000-000000000f73', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f62', date_trunc('month', current_date + interval '16 months')::date, 'NG5', 10),
  ('00000000-0000-4000-8000-000000000f74', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f63', date_trunc('month', current_date + interval '1 month')::date, 'BA7', 1),
  ('00000000-0000-4000-8000-000000000f75', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f64', date_trunc('month', current_date + interval '20 months')::date, 'ST2', 9);
insert into public.open_items (id, clinic_id, product_id, opened_by, opened_at) values
  ('00000000-0000-4000-8000-000000000f81', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f63', '00000000-0000-4000-8000-000000000f31', now() - interval '3 days');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.detail(p uuid) returns jsonb language sql as $$ select public.product_detail(p) $$;
-- The app's body: only the corrected products, counted unopened quantities, one idempotency key.
create function pg_temp.apply_count(p_key uuid) returns uuid language sql as $$
  select public.stock_count_apply(
    '00000000-0000-4000-8000-000000000f41',
    '[{"product_id":"00000000-0000-4000-8000-000000000f61","counted":4},
      {"product_id":"00000000-0000-4000-8000-000000000f62","counted":12},
      {"product_id":"00000000-0000-4000-8000-000000000f63","counted":2}]',
    p_key)
$$;

select pg_temp.act_as('00000000-0000-4000-8000-000000000f32');
select results_eq(
  $$ select name, status from public.inventory_list('00000000-0000-4000-8000-000000000f41') where name <> 'Suction tips' order by name $$,
  $$ values ('Bonding agent', 'expiring'), ('Endo file kit #15-40', 'low'), ('Nitrile gloves M', 'healthy') $$,
  'the three products sit under three different filters before the count');
select lives_ok($$ select pg_temp.apply_count('00000000-0000-4000-8000-000000000fa1') $$, 'staff apply the count');
select results_eq(
  $$ select name, quantity, unopened, open_count from public.inventory_list('00000000-0000-4000-8000-000000000f41') order by name $$,
  $$ values ('Bonding agent', 3::numeric, 2::numeric, 1), ('Endo file kit #15-40', 4::numeric, 4::numeric, 0),
            ('Nitrile gloves M', 12::numeric, 12::numeric, 0), ('Suction tips', 9::numeric, 9::numeric, 0) $$,
  'the list shows the counted quantities; the open bottle stays open');
select results_eq(
  $$ select p.name, t.delta, t.reason, t.by_user from public.transactions t join public.products p on p.id = t.product_id
     where t.type = 'count' order by p.name $$,
  $$ values ('Bonding agent', 1::numeric, 'Physical count', '00000000-0000-4000-8000-000000000f32'::uuid),
            ('Endo file kit #15-40', 3::numeric, 'Physical count', '00000000-0000-4000-8000-000000000f32'::uuid),
            ('Nitrile gloves M', -2::numeric, 'Physical count', '00000000-0000-4000-8000-000000000f32'::uuid) $$,
  'one Physical count transaction per changed product, by whoever counted');
select ok(
  (select bool_and((pg_temp.detail(id) ->> 'last_counted_at')::timestamptz > now() - interval '1 minute')
   from public.products where id in ('00000000-0000-4000-8000-000000000f61', '00000000-0000-4000-8000-000000000f62', '00000000-0000-4000-8000-000000000f63')),
  'Product detail reads Counted today for all three');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000f64') ->> 'last_counted_at', null, 'a product left at its estimate was not counted');
select results_eq(
  $$ select h ->> 'type', (h ->> 'qty_before')::numeric, (h ->> 'qty_after')::numeric, h ->> 'by_name', h ->> 'reason'
     from jsonb_array_elements(pg_temp.detail('00000000-0000-4000-8000-000000000f62') -> 'history') h limit 1 $$,
  $$ values ('count', 14::numeric, 12::numeric, 'Michael Reyes', 'Physical count') $$,
  'the history row reads 14 → 12, Physical count, Michael');
select is(
  (select qty from public.batches where id = '00000000-0000-4000-8000-000000000f72'), 2::numeric,
  'the gloves came off the soonest batch');
select is(
  (select sum(qty) from public.batches where product_id = '00000000-0000-4000-8000-000000000f61' and expiry_month is null), 3::numeric,
  'the three extra kits are undated stock');
select results_eq(
  $$ select name, status from public.inventory_list('00000000-0000-4000-8000-000000000f41') where name <> 'Suction tips' order by name $$,
  $$ values ('Bonding agent', 'expiring'), ('Endo file kit #15-40', 'missing_expiry'), ('Nitrile gloves M', 'healthy') $$,
  'the statuses follow: the kits are no longer low but miss an expiry');
select lives_ok($$ select pg_temp.apply_count('00000000-0000-4000-8000-000000000fa1') $$, 'a replay of the queued count is accepted');
select is((select count(*) from public.transactions where type = 'count'), 3::bigint, 'and writes nothing twice');
select throws_ok(
  $$ select public.stock_count_apply('00000000-0000-4000-8000-000000000f41',
     '[{"product_id":"00000000-0000-4000-8000-000000000f64","counted":-1}]', '00000000-0000-4000-8000-000000000fa2') $$,
  '22023', null, 'a count cannot be negative');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000f33');
select throws_ok(
  $$ select public.stock_count_apply('00000000-0000-4000-8000-000000000f41',
     '[{"product_id":"00000000-0000-4000-8000-000000000f64","counted":1}]', '00000000-0000-4000-8000-000000000fa3') $$,
  '42501', null, 'another clinic cannot count Smile Dental''s stock');
select throws_ok(
  $$ select public.stock_count_apply('00000000-0000-4000-8000-000000000f42',
     '[{"product_id":"00000000-0000-4000-8000-000000000f64","counted":1}]', '00000000-0000-4000-8000-000000000fa4') $$,
  '42501', null, 'nor pass it off as its own product');
reset role;
select is((select qty from public.batches where id = '00000000-0000-4000-8000-000000000f75'), 9::numeric, 'Suction tips are untouched');

select * from finish();
rollback;
