-- MS-135 · inventory_value: Inventory value's figures at the last unit cost, clinic-isolated.
begin;
select plan(18);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000013501', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000013502', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000013503', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone) values
  ('00000000-0000-4000-8000-000000013511', 'Smile Dental', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-000000013512', 'Other Dental', 'CA', 'CAD', 'America/Toronto');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013501', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013502', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000013512', '00000000-0000-4000-8000-000000013503', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
insert into public.categories (id, clinic_id, name) values
  ('00000000-0000-4000-8000-000000013521', '00000000-0000-4000-8000-000000013511', 'Anesthetic'),
  ('00000000-0000-4000-8000-000000013522', '00000000-0000-4000-8000-000000013511', 'Restorative'),
  ('00000000-0000-4000-8000-000000013523', '00000000-0000-4000-8000-000000013511', 'Endodontics'),
  ('00000000-0000-4000-8000-000000013524', '00000000-0000-4000-8000-000000013511', 'Impression');
-- Septocaine 54 × 1.80 = 97.20, Composite A2 (1 unopened, 1 open) 2 × 42 = 84, Bonding agent (1 open) 82,
-- gloves without a category 14 × 5.60 = 78.40, Endo file kit 45, Paper points 2: 388.60 in all. Gauze is in stock
-- without a cost, Suture has neither stock nor cost, Old file is archived; Other Dental holds 100 × 3 = 300.
insert into public.products (id, clinic_id, name, category_id, unit, tracking, last_unit_cost, archived_at) values
  ('00000000-0000-4000-8000-000000013531', '00000000-0000-4000-8000-000000013511', 'Septocaine', '00000000-0000-4000-8000-000000013521', 'cartridges', 'countable', 1.80, null),
  ('00000000-0000-4000-8000-000000013532', '00000000-0000-4000-8000-000000013511', 'Composite A2', '00000000-0000-4000-8000-000000013522', 'syringes', 'multi_use', 42.00, null),
  ('00000000-0000-4000-8000-000000013533', '00000000-0000-4000-8000-000000013511', 'Bonding agent', '00000000-0000-4000-8000-000000013522', 'bottles', 'multi_use', 82.00, null),
  ('00000000-0000-4000-8000-000000013534', '00000000-0000-4000-8000-000000013511', 'Nitrile gloves M', null, 'boxes', 'countable', 5.60, null),
  ('00000000-0000-4000-8000-000000013535', '00000000-0000-4000-8000-000000013511', 'Endo file kit', '00000000-0000-4000-8000-000000013523', 'kits', 'countable', 45.00, null),
  ('00000000-0000-4000-8000-000000013536', '00000000-0000-4000-8000-000000013511', 'Gauze', '00000000-0000-4000-8000-000000013522', 'packs', 'countable', null, null),
  ('00000000-0000-4000-8000-000000013537', '00000000-0000-4000-8000-000000013511', 'Suture', '00000000-0000-4000-8000-000000013524', 'packs', 'countable', null, null),
  ('00000000-0000-4000-8000-000000013538', '00000000-0000-4000-8000-000000013511', 'Old file', '00000000-0000-4000-8000-000000013523', 'files', 'countable', 10.00, now()),
  ('00000000-0000-4000-8000-000000013539', '00000000-0000-4000-8000-000000013511', 'Paper points', '00000000-0000-4000-8000-000000013523', 'packs', 'countable', 2.00, null),
  ('00000000-0000-4000-8000-000000013540', '00000000-0000-4000-8000-000000013512', 'Other gloves', null, 'boxes', 'countable', 3.00, null);
-- Septocaine's lot B441 expires next month (34 × 1.80 = 61.20 at risk), lot A112 in a year.
insert into public.batches (clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013531', date_trunc('month', now() + interval '1 month')::date, 'B441', 34),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013531', date_trunc('month', now() + interval '12 months')::date, 'A112', 20),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013532', null, null, 1),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013534', null, null, 14),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013535', null, null, 1),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013536', null, null, 8),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013538', null, null, 5),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013539', null, null, 1),
  ('00000000-0000-4000-8000-000000013512', '00000000-0000-4000-8000-000000013540', null, null, 100);
-- A Filling two days ago used 2 Septocaine and opened a Composite A2 (3.60 + 42); a Crown five days ago was
-- cancelled; a Root canal 40 days ago is outside the window; an Extraction yesterday used a Suture without a cost
-- and an Old file, archived since (10). Used, 30 d: 55.60.
insert into public.procedure_events (id, clinic_id, name, started_by, started_at, cancelled_at, cancelled_by, cancel_note) values
  ('00000000-0000-4000-8000-000000013551', '00000000-0000-4000-8000-000000013511', 'Filling', '00000000-0000-4000-8000-000000013501', now() - interval '2 days', null, null, null),
  ('00000000-0000-4000-8000-000000013552', '00000000-0000-4000-8000-000000013511', 'Crown', '00000000-0000-4000-8000-000000013502', now() - interval '5 days', now() - interval '4 days', '00000000-0000-4000-8000-000000013502', 'Logged by mistake'),
  ('00000000-0000-4000-8000-000000013553', '00000000-0000-4000-8000-000000013511', 'Root canal', '00000000-0000-4000-8000-000000013501', now() - interval '40 days', null, null, null),
  ('00000000-0000-4000-8000-000000013554', '00000000-0000-4000-8000-000000013511', 'Extraction', '00000000-0000-4000-8000-000000013502', now() - interval '1 day', null, null, null),
  ('00000000-0000-4000-8000-000000013555', '00000000-0000-4000-8000-000000013512', 'Other clinic procedure', '00000000-0000-4000-8000-000000013503', now() - interval '1 day', null, null, null);
insert into public.procedure_event_items (clinic_id, event_id, product_id, qty) values
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013551', '00000000-0000-4000-8000-000000013531', 2),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013551', '00000000-0000-4000-8000-000000013532', 0),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013552', '00000000-0000-4000-8000-000000013531', 3),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013553', '00000000-0000-4000-8000-000000013531', 10),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013554', '00000000-0000-4000-8000-000000013537', 1),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013554', '00000000-0000-4000-8000-000000013538', 1),
  ('00000000-0000-4000-8000-000000013512', '00000000-0000-4000-8000-000000013555', '00000000-0000-4000-8000-000000013540', 50);
insert into public.open_items (id, clinic_id, product_id, opened_by, opened_in_event_id) values
  ('00000000-0000-4000-8000-000000013561', '00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013532', '00000000-0000-4000-8000-000000013501', '00000000-0000-4000-8000-000000013551'),
  ('00000000-0000-4000-8000-000000013562', '00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013533', '00000000-0000-4000-8000-000000013501', null);
insert into public.procedure_event_openings (clinic_id, event_id, product_id, open_item_id) values
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013551', '00000000-0000-4000-8000-000000013532', '00000000-0000-4000-8000-000000013561');
-- Received, 30 d: 20 Septocaine three days ago (36), an Endo file kit received and undone ten days ago (0), not
-- the Composite A2 of 40 days ago, an adjustment or Other Dental's delivery.
insert into public.transactions (id, clinic_id, product_id, type, delta, qty_before, qty_after, by_user, at, ref_type, reverses_id, action_id) values
  ('00000000-0000-4000-8000-000000013571', '00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013531', 'receiving', 20, 34, 54, '00000000-0000-4000-8000-000000013501', now() - interval '3 days', 'manual', null, gen_random_uuid()),
  ('00000000-0000-4000-8000-000000013572', '00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013535', 'receiving', 1, 0, 1, '00000000-0000-4000-8000-000000013501', now() - interval '10 days', 'manual', null, gen_random_uuid());
insert into public.transactions (clinic_id, product_id, type, delta, qty_before, qty_after, by_user, at, ref_type, reverses_id, action_id) values
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013535', 'receiving', -1, 1, 0, '00000000-0000-4000-8000-000000013501', now() - interval '10 days' + interval '5 seconds', 'undo', '00000000-0000-4000-8000-000000013572', gen_random_uuid()),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013532', 'receiving', 2, 0, 2, '00000000-0000-4000-8000-000000013501', now() - interval '40 days', 'manual', null, gen_random_uuid()),
  ('00000000-0000-4000-8000-000000013511', '00000000-0000-4000-8000-000000013531', 'adjustment', 5, 49, 54, '00000000-0000-4000-8000-000000013501', now() - interval '1 day', 'manual', null, gen_random_uuid()),
  ('00000000-0000-4000-8000-000000013512', '00000000-0000-4000-8000-000000013540', 'receiving', 100, 0, 100, '00000000-0000-4000-8000-000000013503', now() - interval '1 day', 'manual', null, gen_random_uuid());

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create function pg_temp.figure(p_key text) returns numeric language sql as $$
  select (public.inventory_value('00000000-0000-4000-8000-000000013511')->>p_key)::numeric;
$$;

select ok(not has_function_privilege('anon', 'public.inventory_value(uuid)', 'execute'), 'anon cannot read the value');
select ok(has_function_privilege('authenticated', 'public.inventory_value(uuid)', 'execute'), 'members can');

select pg_temp.act_as('00000000-0000-4000-8000-000000013502');
select is(pg_temp.figure('total'), 388.60,
  'staff read the total at the last unit cost: a product without a cost counts 0, an archived one nothing');
select is(pg_temp.figure('total'),
  (select sum(s.quantity * coalesce(p.last_unit_cost, 0)) from public.products p
     join public.product_stock s on s.product_id = p.id
    where p.clinic_id = '00000000-0000-4000-8000-000000013511' and p.archived_at is null),
  'acceptance: the total equals Σ quantity × last unit cost in the database');
select is(pg_temp.figure('total'),
  (select inventory_value from public.clinic_attention where clinic_id = '00000000-0000-4000-8000-000000013511'),
  'and Home''s Inventory value tile');
select is(pg_temp.figure('at_risk_90'), 61.20, 'Expiring ≤ 90 d is the value of the batches expiring within 90 days');
select is(pg_temp.figure('used_30'), 55.60,
  'Used, 30 d counts the supplies and opened bottles of procedures of the last 30 days, a cancelled one not at all');
select is(pg_temp.figure('received_30'), 36.00, 'Received, 30 d counts the last 30 days of receiving, net of an Undo');
select is(pg_temp.figure('uncosted_count'), 1::numeric, 'a product in stock without a cost is counted; one without stock is not');
select results_eq(
  $$ select c->>'name', (c->>'value')::numeric, (c->>'product_count')::integer
       from jsonb_array_elements(public.inventory_value('00000000-0000-4000-8000-000000013511')->'categories') c $$,
  $$ values ('Restorative'::text, 166.00, 3), ('Anesthetic', 97.20, 1), (null, 78.40, 1), ('Endodontics', 47.00, 2) $$,
  'categories come largest first, products without one grouped, a category worth nothing left out');
select is(
  (select c->>'category_id' from jsonb_array_elements(public.inventory_value('00000000-0000-4000-8000-000000013511')->'categories') c
    where c->>'name' = 'Anesthetic'),
  '00000000-0000-4000-8000-000000013521', 'a category carries its id for the Inventory filter');
select results_eq(
  $$ select p->>'name' from jsonb_array_elements(public.inventory_value('00000000-0000-4000-8000-000000013511')->'top_products') p $$,
  $$ values ('Septocaine'), ('Composite A2'), ('Bonding agent'), ('Nitrile gloves M'), ('Endo file kit') $$,
  'the five most valuable products come largest first');
select results_eq(
  $$ select p->>'product_id', p->>'unit', (p->>'quantity')::numeric, (p->>'unit_cost')::numeric, (p->>'value')::numeric
       from jsonb_array_elements(public.inventory_value('00000000-0000-4000-8000-000000013511')->'top_products') p
      where p->>'name' = 'Septocaine' $$,
  $$ values ('00000000-0000-4000-8000-000000013531', 'cartridges', 54::numeric, 1.80, 97.20) $$,
  'a product carries its quantity, unit, last unit cost and value');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000013503');
select ok(
  (select (v->>'total')::numeric = 0 and (v->>'used_30')::numeric = 0 and (v->>'received_30')::numeric = 0
      and v->'categories' = '[]'::jsonb and v->'top_products' = '[]'::jsonb
     from public.inventory_value('00000000-0000-4000-8000-000000013511') v),
  'Other Dental sees nothing of Smile Dental''s value');
select is((public.inventory_value('00000000-0000-4000-8000-000000013512')->>'total')::numeric, 300.00, 'it sees its own');
reset role;

-- Acceptance: Sarah receives 6 Septocaine at a new cost of 2.00; the product counts 60 × 2.00 from then on.
select pg_temp.act_as('00000000-0000-4000-8000-000000013501');
select lives_ok($$ select public.stock_receive('00000000-0000-4000-8000-000000013511',
  '[{"product_id": "00000000-0000-4000-8000-000000013531", "qty": 6, "unit_cost": 2.00}]'::jsonb, gen_random_uuid()) $$,
  'Sarah receives 6 Septocaine at 2.00');
select is(pg_temp.figure('total'), 411.40, 'an admin reads it too, and a receipt at a new cost revalues the product');
select is(pg_temp.figure('received_30'), 52.00, 'the month''s receipts follow the last unit cost');
reset role;

select * from finish();
rollback;
