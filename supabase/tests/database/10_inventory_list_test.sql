-- MS-115 · inventory_list: one row per active product with category, figures and status, clinic-isolated.
begin;
select plan(12);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000000c31', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member@dentory.test'),
  ('00000000-0000-4000-8000-000000000c32', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test'),
  ('00000000-0000-4000-8000-000000000c33', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'nobody@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-000000000c41', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', '{90}'),
  ('00000000-0000-4000-8000-000000000c42', 'Other Dental', 'CA', 'CAD', 'America/Toronto', '{90}');
insert into public.memberships (clinic_id, user_id, email, role, status) values
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c31', 'member@dentory.test', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000000c42', '00000000-0000-4000-8000-000000000c32', 'elsewhere@dentory.test', 'admin', 'active');
insert into public.categories (id, clinic_id, name, position) values
  ('00000000-0000-4000-8000-000000000c51', '00000000-0000-4000-8000-000000000c41', 'Anesthetic', 1),
  ('00000000-0000-4000-8000-000000000c52', '00000000-0000-4000-8000-000000000c41', 'Restorative', 2);
insert into public.products (id, clinic_id, name, category_id, unit, tracking, minimum, target, location) values
  ('00000000-0000-4000-8000-000000000c61', '00000000-0000-4000-8000-000000000c41', 'Septocaine 4% 1:100,000', '00000000-0000-4000-8000-000000000c51', 'cartridges', 'countable', 20, 60, 'Operatory 1 · Drawer A'),
  ('00000000-0000-4000-8000-000000000c62', '00000000-0000-4000-8000-000000000c41', 'Composite A2', '00000000-0000-4000-8000-000000000c52', 'syringes', 'multi_use', 2, 6, null),
  ('00000000-0000-4000-8000-000000000c63', '00000000-0000-4000-8000-000000000c41', 'Gauze', null, 'packs', 'countable', 4, 10, null),
  ('00000000-0000-4000-8000-000000000c64', '00000000-0000-4000-8000-000000000c42', 'Other clinic product', null, 'packs', 'countable', 0, 1, null);
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target, archived_at) values
  ('00000000-0000-4000-8000-000000000c65', '00000000-0000-4000-8000-000000000c41', 'Old gauze', 'packs', 'countable', 5, 10, now());
-- Septocaine: 54 dated far out. Composite: 1 unopened dated, 1 open. Gauze: nothing.
insert into public.batches (clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c61', date_trunc('month', current_date + interval '8 months')::date, 'A1', 54),
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c62', date_trunc('month', current_date + interval '8 months')::date, 'B1', 1);
insert into public.open_items (clinic_id, product_id, opened_by) values
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c62', '00000000-0000-4000-8000-000000000c31');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

select ok(not has_function_privilege('anon', 'public.inventory_list(uuid)', 'execute'), 'anon cannot list an inventory');
select ok(has_function_privilege('authenticated', 'public.inventory_list(uuid)', 'execute'), 'members can');

-- A member sees the clinic's active products, by name, with figures and status.
select pg_temp.act_as('00000000-0000-4000-8000-000000000c31');
select results_eq(
  $$ select name, category_name, unit, tracking, location, quantity, unopened, open_count, minimum, status
     from public.inventory_list('00000000-0000-4000-8000-000000000c41') $$,
  $$ values
     ('Composite A2', 'Restorative', 'syringes', 'multi_use', null::text, 2::numeric, 1::numeric, 1, 2::numeric, 'low'),
     ('Gauze', null::text, 'packs', 'countable', null::text, 0::numeric, 0::numeric, 0, 4::numeric, 'out_of_stock'),
     ('Septocaine 4% 1:100,000', 'Anesthetic', 'cartridges', 'countable', 'Operatory 1 · Drawer A', 54::numeric, 54::numeric, 0, 20::numeric, 'healthy') $$,
  'the list carries name, category, unit, tracking, location, the stock figures and the status, by name');
select is((select count(*)::integer from public.inventory_list('00000000-0000-4000-8000-000000000c41') where name = 'Old gauze'), 0,
  'an archived product is left out');
select is((select count(*)::integer from public.inventory_list('00000000-0000-4000-8000-000000000c42')), 0,
  'another clinic reads as empty to a member of this one');
select is((select product_id from public.inventory_list('00000000-0000-4000-8000-000000000c41') where name = 'Gauze'),
  '00000000-0000-4000-8000-000000000c63'::uuid, 'rows carry the product id');
reset role;

-- The other clinic's admin sees only their own product.
select pg_temp.act_as('00000000-0000-4000-8000-000000000c32');
select results_eq($$ select name from public.inventory_list('00000000-0000-4000-8000-000000000c42') $$,
  $$ values ('Other clinic product') $$, 'the other clinic lists its own product');
select is((select count(*)::integer from public.inventory_list('00000000-0000-4000-8000-000000000c41')), 0,
  'and nothing of Smile Dental');
reset role;

-- A user with no membership sees nothing anywhere.
select pg_temp.act_as('00000000-0000-4000-8000-000000000c33');
select is((select count(*)::integer from public.inventory_list('00000000-0000-4000-8000-000000000c41')), 0, 'a stranger sees nothing');
reset role;

-- The status follows the stock: receiving gauze makes it healthy, with the category still null.
insert into public.batches (clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c63', date_trunc('month', current_date + interval '8 months')::date, 'G1', 10);
select pg_temp.act_as('00000000-0000-4000-8000-000000000c31');
select is((select status from public.inventory_list('00000000-0000-4000-8000-000000000c41') where name = 'Gauze'), 'healthy', 'gauze is healthy once stocked');
select is((select quantity from public.inventory_list('00000000-0000-4000-8000-000000000c41') where name = 'Gauze'), 10::numeric, 'with its quantity');
select is((select count(*)::integer from public.inventory_list('00000000-0000-4000-8000-000000000c41')), 3, 'still three active products');
reset role;

select * from finish();
rollback;
