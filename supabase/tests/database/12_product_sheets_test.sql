-- MS-117 · Create, edit and delete products: categories found or created, levels and tracking rules, alerts
-- following the levels, and Delete product archiving with the templates and open To buy lines cleared.
begin;
select plan(37);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000000e31', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000000e32', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000000e33', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-000000000e41', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', '{90}'),
  ('00000000-0000-4000-8000-000000000e42', 'Other Dental', 'CA', 'CAD', 'America/Toronto', '{90}');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e31', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e32', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000000e42', '00000000-0000-4000-8000-000000000e33', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
insert into public.categories (id, clinic_id, name, position) values
  ('00000000-0000-4000-8000-000000000e51', '00000000-0000-4000-8000-000000000e41', 'Anesthetic', 1),
  ('00000000-0000-4000-8000-000000000e52', '00000000-0000-4000-8000-000000000e41', 'Restorative', 2);
insert into public.products (id, clinic_id, name, category_id, unit, pack_unit, pack_size, tracking, minimum, target, supplier) values
  ('00000000-0000-4000-8000-000000000e61', '00000000-0000-4000-8000-000000000e41', 'Septocaine 4% 1:100,000', '00000000-0000-4000-8000-000000000e51', 'cartridges', 'box', 50, 'countable', 20, 60, 'Patterson'),
  ('00000000-0000-4000-8000-000000000e62', '00000000-0000-4000-8000-000000000e41', 'Bonding agent', '00000000-0000-4000-8000-000000000e52', 'bottles', null, null, 'multi_use', 0, 2, 'Henry Schein');
-- Septocaine: 58 in stock. Bonding: 2 unopened, 1 open.
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000000e71', '00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e61', date_trunc('month', current_date + interval '8 months')::date, 'B441', 34),
  ('00000000-0000-4000-8000-000000000e72', '00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e61', date_trunc('month', current_date + interval '9 months')::date, 'A112', 20),
  ('00000000-0000-4000-8000-000000000e73', '00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e61', null, null, 4),
  ('00000000-0000-4000-8000-000000000e74', '00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e62', date_trunc('month', current_date + interval '8 months')::date, 'BA7', 2);
insert into public.open_items (id, clinic_id, product_id, opened_by, opened_at) values
  ('00000000-0000-4000-8000-000000000e81', '00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e62', '00000000-0000-4000-8000-000000000e31', now() - interval '3 days');
insert into public.transactions (clinic_id, product_id, type, delta, qty_before, qty_after, by_user, at, ref_type, ref_label, reason, action_id) values
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e61', 'receiving', 60, 0, 60, '00000000-0000-4000-8000-000000000e31', now() - interval '40 days', 'invoice', 'Invoice INV-10092', null, gen_random_uuid()),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e61', 'procedure', -2, 60, 58, '00000000-0000-4000-8000-000000000e31', now() - interval '1 day', 'procedure_event', 'Root canal', null, gen_random_uuid());
insert into public.procedure_templates (id, clinic_id, name) values
  ('00000000-0000-4000-8000-000000000e91', '00000000-0000-4000-8000-000000000e41', 'Root canal');
insert into public.procedure_template_items (clinic_id, template_id, product_id, default_qty) values
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e91', '00000000-0000-4000-8000-000000000e61', 2),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e91', '00000000-0000-4000-8000-000000000e62', 0);
insert into public.to_buy_items (id, clinic_id, product_id, qty, source, status, added_by, ordered_at, ordered_by, received_at) values
  ('00000000-0000-4000-8000-000000000ea1', '00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e61', 10, 'manual', 'to_buy', '00000000-0000-4000-8000-000000000e31', null, null, null),
  ('00000000-0000-4000-8000-000000000ea2', '00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e61', 20, 'auto', 'ordered', null, now() - interval '2 days', '00000000-0000-4000-8000-000000000e31', null),
  ('00000000-0000-4000-8000-000000000ea3', '00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e61', 30, 'auto', 'received', null, now() - interval '20 days', '00000000-0000-4000-8000-000000000e31', now() - interval '10 days');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

-- Privileges
select ok(not has_function_privilege('anon', 'public.product_archive(uuid)', 'execute'), 'anon cannot archive');
select ok(has_function_privilege('authenticated', 'public.product_archive(uuid)', 'execute'), 'members reach product_archive (it checks the role itself)');
select ok(not has_function_privilege('anon', 'public.category_find_or_create(uuid, text)', 'execute'), 'anon cannot create categories');

-- Categories: found whatever the case, created trimmed, admins only
select pg_temp.act_as('00000000-0000-4000-8000-000000000e31');
select is(
  (public.category_find_or_create('00000000-0000-4000-8000-000000000e41', 'anesthetic') ->> 'id')::uuid,
  '00000000-0000-4000-8000-000000000e51'::uuid, 'an existing category is found whatever the case');
select is(public.category_find_or_create('00000000-0000-4000-8000-000000000e41', '  Orthodontics ') ->> 'name', 'Orthodontics', 'a new category is created trimmed');
select is(
  (public.category_find_or_create('00000000-0000-4000-8000-000000000e41', 'orthodontics') ->> 'id')::uuid,
  (select id from public.categories where clinic_id = '00000000-0000-4000-8000-000000000e41' and name = 'Orthodontics'), 'and found the second time');
select is((select position from public.categories where name = 'Orthodontics'), 3, 'a new category goes to the end of the list');
select throws_ok(
  $$ select public.category_find_or_create('00000000-0000-4000-8000-000000000e41', '   ') $$,
  '22023', 'Enter a category name of 60 characters or fewer.', 'an empty name is refused');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000000e32');
select throws_ok(
  $$ select public.category_find_or_create('00000000-0000-4000-8000-000000000e41', 'Lab') $$,
  '42501', null, 'staff cannot create a category');
reset role;

-- Levels: a new product without stock is Out of stock and gets its alert and auto To buy line at its first
-- stock or level change (or from refresh_all_products at 07:00), not on insert or on an edit that keeps the
-- levels; target under minimum is refused; raising the minimum above the stock opens Low, lowering it resolves Low
select pg_temp.act_as('00000000-0000-4000-8000-000000000e31');
select lives_ok(
  $$ insert into public.products (id, clinic_id, name, unit, minimum, target)
     values ('00000000-0000-4000-8000-000000000e63', '00000000-0000-4000-8000-000000000e41', 'Articaine 4%', 'cartridges', 5, 10) $$,
  'an admin creates a product through the policies');
select is((select status from public.product_status where product_id = '00000000-0000-4000-8000-000000000e63'), 'out_of_stock', 'a product without stock is Out of stock');
select throws_ok(
  $$ update public.products set target = 10 where id = '00000000-0000-4000-8000-000000000e61' $$,
  '22023', 'Target must be at least the minimum.', 'a target under the minimum is refused');
select lives_ok(
  $$ update public.products set minimum = 59 where id = '00000000-0000-4000-8000-000000000e61' $$,
  'the minimum can rise above the stock (58) while staying under the target');
reset role;
select ok(not exists (
  select 1 from public.alerts where product_id = '00000000-0000-4000-8000-000000000e63' and resolved_at is null),
  'creating a product opens no alert and no To buy line until its first stock or level change');
select is((select count(*) from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000000e63'), 0::bigint, 'no auto To buy line either');
select pg_temp.act_as('00000000-0000-4000-8000-000000000e31');
-- The Edit sheet sends every column: a new name with the same levels is not a level change.
update public.products set name = 'Articaine 4% 1:100,000', minimum = minimum, target = target, tracking = tracking
  where id = '00000000-0000-4000-8000-000000000e63';
reset role;
select ok(
  not exists (select 1 from public.alerts where product_id = '00000000-0000-4000-8000-000000000e63' and resolved_at is null)
  and not exists (select 1 from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000000e63'),
  'an edit that keeps the levels opens nothing either');
select ok(exists (
  select 1 from public.alerts where product_id = '00000000-0000-4000-8000-000000000e61' and kind = 'low' and resolved_at is null),
  'raising the minimum above the stock opened the Low alert');
select pg_temp.act_as('00000000-0000-4000-8000-000000000e31');
select lives_ok(
  $$ update public.products set minimum = 20 where id = '00000000-0000-4000-8000-000000000e61' $$, 'and it goes back down');
reset role;
select ok(not exists (
  select 1 from public.alerts where product_id = '00000000-0000-4000-8000-000000000e61' and kind = 'low' and resolved_at is null),
  'which resolved the Low alert');

-- Tracking: blocked with stock, allowed without
select pg_temp.act_as('00000000-0000-4000-8000-000000000e31');
select throws_ok(
  $$ update public.products set tracking = 'multi_use' where id = '00000000-0000-4000-8000-000000000e61' $$,
  '22023', 'Set stock to 0 before changing how it is tracked.', 'a product with stock keeps how it is tracked');
select lives_ok(
  $$ update public.products set tracking = 'multi_use' where id = '00000000-0000-4000-8000-000000000e63' $$,
  'a product without stock can change how it is tracked');
reset role;
select is((select t.qty from public.to_buy_items t where t.product_id = '00000000-0000-4000-8000-000000000e63' and t.status = 'to_buy'), 10::numeric,
  'the first change to an out-of-stock product opens its auto To buy line for the target');

-- Delete product: admins of the clinic only
select pg_temp.act_as('00000000-0000-4000-8000-000000000e32');
select throws_ok($$ select public.product_archive('00000000-0000-4000-8000-000000000e61') $$, '42501', 'only an admin can do this', 'staff cannot delete a product');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000000e33');
select throws_ok($$ select public.product_archive('00000000-0000-4000-8000-000000000e61') $$, '42501', 'only an admin can do this', 'nor can another clinic''s admin');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000000e31');
select lives_ok($$ select public.product_archive('00000000-0000-4000-8000-000000000e61') $$, 'the admin archives the product');
select is((select count(*) from public.inventory_list('00000000-0000-4000-8000-000000000e41') where product_id = '00000000-0000-4000-8000-000000000e61'), 0::bigint, 'it left the Inventory list');
select is(public.product_detail('00000000-0000-4000-8000-000000000e61') -> 'product', 'null'::jsonb, 'and Product detail');
select throws_ok($$ select public.product_archive('00000000-0000-4000-8000-000000000e61') $$, '22023', 'the product is archived', 'archiving it again is refused');
select is((public.product_detail('00000000-0000-4000-8000-000000000e62') -> 'product' ->> 'category_id')::uuid, '00000000-0000-4000-8000-000000000e52'::uuid, 'Product detail answers the category id for the Edit sheet');
select is(public.product_detail('00000000-0000-4000-8000-000000000e62') -> 'product' ->> 'supplier', 'Henry Schein', 'and the supplier');
reset role;
select ok((select archived_at from public.products where id = '00000000-0000-4000-8000-000000000e61') is not null, 'archived_at is set');
select is((select count(*) from public.procedure_template_items where product_id = '00000000-0000-4000-8000-000000000e61'), 0::bigint, 'the product left every template');
select is((select count(*) from public.procedure_template_items where template_id = '00000000-0000-4000-8000-000000000e91'), 1::bigint, 'the other item of the template stays');
select is((select count(*) from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000000e61' and status in ('to_buy', 'ordered')), 0::bigint, 'its open To buy lines are gone');
select is((select count(*) from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000000e61'), 1::bigint, 'the received line stays as history');
select is((select count(*) from public.transactions where product_id = '00000000-0000-4000-8000-000000000e61'), 2::bigint, 'the ledger is kept');
select ok(not exists (select 1 from public.alerts where product_id = '00000000-0000-4000-8000-000000000e61' and resolved_at is null), 'its alerts are resolved');

select * from finish();
rollback;
