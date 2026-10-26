-- MS-127 · Receive manually: Choose product lists an admin's active products with their pack and stock (Staff and other
-- clinics refused), and the receipt the form sends through stock_receive (one line in counted units, the cost per
-- counted unit, ref_type 'manual') lands as the acceptance criterion says: 5 boxes of a 50-pack add 250 to a batch with
-- the lot and expiry given, the last unit cost follows, the product's To buy line is received, a multi-use product gains
-- unopened units, and a read-only clinic is refused.
begin;
select plan(29);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000036101', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000036102', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000036103', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone) values
  ('00000000-0000-4000-8000-000000036111', 'Smile Dental', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-000000036112', 'Other Dental', 'CA', 'CAD', 'America/Toronto');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000036111', '00000000-0000-4000-8000-000000036101', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000036111', '00000000-0000-4000-8000-000000036102', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000036112', '00000000-0000-4000-8000-000000036103', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
insert into public.categories (id, clinic_id, name) values
  ('00000000-0000-4000-8000-000000036131', '00000000-0000-4000-8000-000000036111', 'Anesthetic');
-- Septocaine comes in boxes of 50 and holds 54; Root canal sealer is multi-use with 1 unopened and 1 open; Gauze is
-- empty with a last cost; Old gloves were deleted (archived); the other clinic has its own product.
insert into public.products (id, clinic_id, name, category_id, unit, pack_unit, pack_size, tracking, minimum, target, last_unit_cost, archived_at) values
  ('00000000-0000-4000-8000-000000036121', '00000000-0000-4000-8000-000000036111', 'Septocaine 4% 1:100,000', '00000000-0000-4000-8000-000000036131', 'cartridges', 'box', 50, 'countable', 20, 60, 1.20, null),
  ('00000000-0000-4000-8000-000000036122', '00000000-0000-4000-8000-000000036111', 'Root canal sealer', null, 'kits', null, null, 'multi_use', 1, 3, null, null),
  ('00000000-0000-4000-8000-000000036123', '00000000-0000-4000-8000-000000036111', 'Gauze', null, 'packs', null, null, 'countable', 4, 10, 3.20, null),
  ('00000000-0000-4000-8000-000000036124', '00000000-0000-4000-8000-000000036111', 'Old gloves', null, 'boxes', null, null, 'countable', 0, 0, null, now()),
  ('00000000-0000-4000-8000-000000036125', '00000000-0000-4000-8000-000000036112', 'Other clinic product', null, 'packs', null, null, 'countable', 0, 0, null, null);
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000036141', '00000000-0000-4000-8000-000000036111', '00000000-0000-4000-8000-000000036121', (date_trunc('month', current_date) + interval '12 months')::date, 'B441', 54),
  ('00000000-0000-4000-8000-000000036142', '00000000-0000-4000-8000-000000036111', '00000000-0000-4000-8000-000000036122', null, null, 1);
insert into public.open_items (clinic_id, product_id, opened_by) values
  ('00000000-0000-4000-8000-000000036111', '00000000-0000-4000-8000-000000036122', '00000000-0000-4000-8000-000000036101');
-- Septocaine was marked ordered; Gauze is still to buy.
insert into public.to_buy_items (id, clinic_id, product_id, qty, status, ordered_at) values
  ('00000000-0000-4000-8000-000000036151', '00000000-0000-4000-8000-000000036111', '00000000-0000-4000-8000-000000036121', 250, 'ordered', now() - interval '1 day'),
  ('00000000-0000-4000-8000-000000036152', '00000000-0000-4000-8000-000000036111', '00000000-0000-4000-8000-000000036123', 10, 'to_buy', null);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.stock(p uuid) returns numeric language sql as $$
  select quantity from public.product_stock where product_id = p
$$;
-- What the form sends: one line in counted units, the cost per counted unit, Receive manually as the reference.
create function pg_temp.receive(p_line jsonb, p_clinic uuid default '00000000-0000-4000-8000-000000036111') returns uuid language sql as $$
  select public.stock_receive(p_clinic, jsonb_build_array(p_line), gen_random_uuid(), 'manual', null, 'Receive manually')
$$;

select ok(not has_function_privilege('anon', 'public.receive_products(uuid)', 'execute'), 'anon cannot list them');
select ok(has_function_privilege('authenticated', 'public.receive_products(uuid)', 'execute'), 'members can call it');

-- Staff: no entry point in the app, and the calls themselves are refused.
select pg_temp.act_as('00000000-0000-4000-8000-000000036102');
select throws_ok($$ select * from public.receive_products('00000000-0000-4000-8000-000000036111') $$,
  '42501', 'Only an admin can receive deliveries', 'Staff cannot list the products to receive');
select throws_ok($$ select pg_temp.receive(jsonb_build_object('product_id', '00000000-0000-4000-8000-000000036123', 'qty', 1)) $$,
  '42501', 'only an admin can do this', 'nor receive');
reset role;

-- Another clinic's admin is refused too, and sees only their own clinic's products.
select pg_temp.act_as('00000000-0000-4000-8000-000000036103');
select throws_ok($$ select * from public.receive_products('00000000-0000-4000-8000-000000036111') $$,
  '42501', 'Only an admin can receive deliveries', 'an admin of another clinic is refused');
select is((select array_agg(name) from public.receive_products('00000000-0000-4000-8000-000000036112')),
  array['Other clinic product'], 'and lists only their own');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000036101');
select is((select array_agg(name) from public.receive_products('00000000-0000-4000-8000-000000036111')),
  array['Gauze', 'Root canal sealer', 'Septocaine 4% 1:100,000'],
  'Choose product lists the active products by name; a deleted one stays out');
select results_eq(
  $$ select category_name, unit, pack_unit, pack_size, tracking, quantity, unopened, open_count
     from public.receive_products('00000000-0000-4000-8000-000000036111') where name like 'Septocaine%' $$,
  $$ values ('Anesthetic'::text, 'cartridges'::text, 'box'::text, 50, 'countable'::text, 54::numeric, 54::numeric, 0) $$,
  'a product received in packs carries its pack, its size and its stock');
select results_eq(
  $$ select category_name, unit, pack_unit, pack_size, tracking, quantity, unopened, open_count
     from public.receive_products('00000000-0000-4000-8000-000000036111') where name = 'Root canal sealer' $$,
  $$ values (null::text, 'kits'::text, null::text, null::integer, 'multi_use'::text, 2::numeric, 1::numeric, 1) $$,
  'a multi-use product carries its unopened and open counts; no category and no pack read null');

-- The acceptance criterion: 5 boxes of a 50-pack at $49.80 a box arrive as 250 cartridges at $0.996 each.
select lives_ok($$ select pg_temp.receive(jsonb_build_object(
    'product_id', '00000000-0000-4000-8000-000000036121', 'qty', 250, 'unit_cost', 0.996, 'lot', 'L-77',
    'expiry_month', (date_trunc('month', current_date) + interval '12 months')::date)) $$,
  'the admin receives 5 boxes');
select is(pg_temp.stock('00000000-0000-4000-8000-000000036121'), 304::numeric, 'the product holds 54 + 250');
select is(
  (select qty from public.batches where product_id = '00000000-0000-4000-8000-000000036121' and lot = 'L-77'
     and expiry_month = (date_trunc('month', current_date) + interval '12 months')::date),
  250::numeric, 'in a batch of its own with the lot and expiry given');
select is((select qty from public.batches where id = '00000000-0000-4000-8000-000000036141'), 54::numeric,
  'the batch with another lot is left as it was');
select is((select last_unit_cost from public.products where id = '00000000-0000-4000-8000-000000036121'), 0.996::numeric,
  'the last unit cost is the cost per cartridge');
select results_eq(
  $$ select type::text, delta, qty_before, qty_after, ref_type::text, ref_label, by_user
     from public.transactions where product_id = '00000000-0000-4000-8000-000000036121' $$,
  $$ values ('receiving'::text, 250::numeric, 54::numeric, 304::numeric, 'manual'::text, 'Receive manually'::text,
             '00000000-0000-4000-8000-000000036101'::uuid) $$,
  'one Receiving row, by the admin, referenced as Receive manually');
select results_eq(
  $$ select status::text, received_at is not null from public.to_buy_items where id = '00000000-0000-4000-8000-000000036151' $$,
  $$ values ('received'::text, true) $$,
  'the line marked ordered is received');
select is(
  (select quantity from public.receive_products('00000000-0000-4000-8000-000000036111') where name like 'Septocaine%'),
  304::numeric, 'Choose product shows the new stock');

-- No cost, lot or expiry: the last unit cost stays and the quantity is undated (Missing expiry).
select lives_ok($$ select pg_temp.receive(jsonb_build_object('product_id', '00000000-0000-4000-8000-000000036123', 'qty', 10)) $$,
  'the admin receives Gauze with nothing but a quantity');
select is((select last_unit_cost from public.products where id = '00000000-0000-4000-8000-000000036123'), 3.20::numeric,
  'without a cost the last unit cost stays');
select is((select missing_expiry_qty from public.product_stock where product_id = '00000000-0000-4000-8000-000000036123'),
  10::numeric, 'without an expiry the quantity is undated');
select results_eq(
  $$ select status::text, received_at is not null, ordered_at is not null from public.to_buy_items
     where id = '00000000-0000-4000-8000-000000036152' $$,
  $$ values ('received'::text, true, true) $$,
  'the line still to buy is received too, dated as ordered');

-- A multi-use product: what arrives is unopened.
select lives_ok($$ select pg_temp.receive(jsonb_build_object('product_id', '00000000-0000-4000-8000-000000036122', 'qty', 4)) $$,
  'the admin receives 4 kits of Root canal sealer');
select results_eq(
  $$ select unopened, open_count, quantity from public.product_stock where product_id = '00000000-0000-4000-8000-000000036122' $$,
  $$ values (5::numeric, 1, 6::numeric) $$,
  'they are unopened; the open one stays open');

-- What the engine refuses.
select throws_ok($$ select pg_temp.receive(jsonb_build_object('product_id', '00000000-0000-4000-8000-000000036123', 'qty', 0)) $$,
  '22023', 'a received quantity must be above 0', 'a quantity of 0 is refused');
select throws_ok($$ select pg_temp.receive(jsonb_build_object('product_id', '00000000-0000-4000-8000-000000036124', 'qty', 1)) $$,
  '22023', 'the product is archived', 'a deleted product is refused');
select throws_ok($$ select pg_temp.receive(jsonb_build_object('product_id', '00000000-0000-4000-8000-000000036125', 'qty', 1)) $$,
  '42501', 'the product belongs to another clinic', 'another clinic''s product is refused');
reset role;

-- A read-only clinic: its admin still reads the list, and the receipt is refused (MS-142).
update public.clinics set trial_ends_at = now() - interval '1 day' where id = '00000000-0000-4000-8000-000000036111';
select pg_temp.act_as('00000000-0000-4000-8000-000000036101');
select ok(not public.clinic_can_write('00000000-0000-4000-8000-000000036111'), 'the clinic is read-only');
select lives_ok($$ select * from public.receive_products('00000000-0000-4000-8000-000000036111') $$,
  'its admin can still list the products');
select throws_ok($$ select pg_temp.receive(jsonb_build_object('product_id', '00000000-0000-4000-8000-000000036121', 'qty', 50)) $$,
  '42501', 'the clinic is read-only until a payment method is added', 'and cannot receive');
reset role;

select * from finish();
rollback;
