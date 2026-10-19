-- MS-116 · product_detail: the product, its figures, batches, open bottles, history and To buy state, clinic-isolated.
begin;
select plan(21);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000000d31', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000000d32', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000000d33', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test'),
  ('00000000-0000-4000-8000-000000000d34', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'nobody@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-000000000d41', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', '{90}'),
  ('00000000-0000-4000-8000-000000000d42', 'Other Dental', 'CA', 'CAD', 'America/Toronto', '{90}');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000000d41', '00000000-0000-4000-8000-000000000d31', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000000d41', '00000000-0000-4000-8000-000000000d32', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000000d42', '00000000-0000-4000-8000-000000000d33', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
insert into public.categories (id, clinic_id, name, position) values
  ('00000000-0000-4000-8000-000000000d51', '00000000-0000-4000-8000-000000000d41', 'Anesthetic', 1);
insert into public.products (id, clinic_id, name, category_id, unit, pack_unit, pack_size, tracking, minimum, target) values
  ('00000000-0000-4000-8000-000000000d61', '00000000-0000-4000-8000-000000000d41', 'Septocaine 4% 1:100,000', '00000000-0000-4000-8000-000000000d51', 'cartridges', 'box', 50, 'countable', 20, 60),
  ('00000000-0000-4000-8000-000000000d62', '00000000-0000-4000-8000-000000000d41', 'Bonding agent', null, 'bottles', null, null, 'multi_use', 1, 3),
  ('00000000-0000-4000-8000-000000000d63', '00000000-0000-4000-8000-000000000d42', 'Other clinic product', null, 'packs', null, null, 'countable', 0, 1);
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target, archived_at) values
  ('00000000-0000-4000-8000-000000000d64', '00000000-0000-4000-8000-000000000d41', 'Old gauze', 'packs', 'countable', 5, 10, now());
-- Septocaine: 20 dated two months out, 34 dated three months out, 4 undated. Bonding: 2 unopened, 1 open.
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000000d71', '00000000-0000-4000-8000-000000000d41', '00000000-0000-4000-8000-000000000d61', date_trunc('month', current_date + interval '3 months')::date, 'B441', 34),
  ('00000000-0000-4000-8000-000000000d72', '00000000-0000-4000-8000-000000000d41', '00000000-0000-4000-8000-000000000d61', date_trunc('month', current_date + interval '2 months')::date, 'A112', 20),
  ('00000000-0000-4000-8000-000000000d73', '00000000-0000-4000-8000-000000000d41', '00000000-0000-4000-8000-000000000d61', null, null, 4),
  ('00000000-0000-4000-8000-000000000d74', '00000000-0000-4000-8000-000000000d41', '00000000-0000-4000-8000-000000000d62', date_trunc('month', current_date + interval '8 months')::date, 'BA7', 2);
insert into public.open_items (id, clinic_id, product_id, opened_by, opened_at) values
  ('00000000-0000-4000-8000-000000000d81', '00000000-0000-4000-8000-000000000d41', '00000000-0000-4000-8000-000000000d62', '00000000-0000-4000-8000-000000000d31', now() - interval '3 days');
-- The ledger: a receiving 40 days ago, an old procedure (outside the 30-day window), a count, a recent procedure.
insert into public.transactions (clinic_id, product_id, type, delta, qty_before, qty_after, by_user, at, ref_type, ref_label, reason, action_id) values
  ('00000000-0000-4000-8000-000000000d41', '00000000-0000-4000-8000-000000000d61', 'receiving', 40, 20, 60, '00000000-0000-4000-8000-000000000d32', now() - interval '40 days', 'invoice', 'Invoice INV-10092', null, gen_random_uuid()),
  ('00000000-0000-4000-8000-000000000d41', '00000000-0000-4000-8000-000000000d61', 'procedure', -5, 60, 55, '00000000-0000-4000-8000-000000000d31', now() - interval '35 days', 'procedure_event', 'Filling', null, gen_random_uuid()),
  ('00000000-0000-4000-8000-000000000d41', '00000000-0000-4000-8000-000000000d61', 'count', -2, 43, 41, '00000000-0000-4000-8000-000000000d32', now() - interval '2 days', 'count_session', null, 'Physical count', gen_random_uuid()),
  ('00000000-0000-4000-8000-000000000d41', '00000000-0000-4000-8000-000000000d61', 'procedure', -2, 41, 39, '00000000-0000-4000-8000-000000000d31', now() - interval '1 day', 'procedure_event', 'Root canal', null, gen_random_uuid());
insert into public.to_buy_items (id, clinic_id, product_id, qty, source, status, added_by) values
  ('00000000-0000-4000-8000-000000000d91', '00000000-0000-4000-8000-000000000d41', '00000000-0000-4000-8000-000000000d62', 2, 'manual', 'to_buy', '00000000-0000-4000-8000-000000000d31');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.detail(p uuid) returns jsonb language sql as $$ select public.product_detail(p) $$;

select ok(not has_function_privilege('anon', 'public.product_detail(uuid)', 'execute'), 'anon cannot read a product');
select ok(has_function_privilege('authenticated', 'public.product_detail(uuid)', 'execute'), 'members can');

select pg_temp.act_as('00000000-0000-4000-8000-000000000d32');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000d61') -> 'product' ->> 'name', 'Septocaine 4% 1:100,000', 'the product carries its name');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000d61') -> 'product' ->> 'category_name', 'Anesthetic', 'and its category');
select is((pg_temp.detail('00000000-0000-4000-8000-000000000d61') -> 'product' ->> 'pack_size')::integer, 50, 'and its pack size');
select is((pg_temp.detail('00000000-0000-4000-8000-000000000d61') -> 'product' ->> 'quantity')::numeric, 58::numeric, 'the quantity is the sum of its batches (20 + 34 + 4 undated)');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000d61') -> 'product' ->> 'status', 'expiring', 'the status follows the soonest batch (two months out, inside the 90-day window)');
select is((pg_temp.detail('00000000-0000-4000-8000-000000000d61') ->> 'used_30d')::numeric, 2::numeric, 'used in 30 days counts the recent procedure only');
select ok((pg_temp.detail('00000000-0000-4000-8000-000000000d61') ->> 'last_counted_at')::timestamptz between now() - interval '3 days' and now() - interval '1 day',
  'last counted at is the count row');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000d61') ->> 'to_buy_item_id', null, 'Septocaine is not on the To buy list');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000d62') ->> 'to_buy_item_id', '00000000-0000-4000-8000-000000000d91', 'Bonding is, with its item id');
select results_eq(
  $$ select b ->> 'lot', (b ->> 'qty')::numeric, b ->> 'expiry_month' is null from jsonb_array_elements(pg_temp.detail('00000000-0000-4000-8000-000000000d61') -> 'batches') b $$,
  $$ values ('A112', 20::numeric, false), ('B441', 34::numeric, false), (null::text, 4::numeric, true) $$,
  'batches come soonest first, the undated one last');
select results_eq(
  $$ select h ->> 'type', (h ->> 'delta')::numeric, h ->> 'by_name', coalesce(h ->> 'ref_label', h ->> 'reason')
     from jsonb_array_elements(pg_temp.detail('00000000-0000-4000-8000-000000000d61') -> 'history') h $$,
  $$ values ('procedure', -2::numeric, 'Sarah Mitchell', 'Root canal'), ('count', -2::numeric, 'Michael Reyes', 'Physical count'),
            ('procedure', -5::numeric, 'Sarah Mitchell', 'Filling'), ('receiving', 40::numeric, 'Michael Reyes', 'Invoice INV-10092') $$,
  'history is newest first with who wrote each row');
select is(jsonb_array_length(pg_temp.detail('00000000-0000-4000-8000-000000000d61') -> 'open_items'), 0, 'a countable product has no open bottles');
select results_eq(
  $$ select o ->> 'opened_by_name' from jsonb_array_elements(pg_temp.detail('00000000-0000-4000-8000-000000000d62') -> 'open_items') o $$,
  $$ values ('Sarah Mitchell') $$, 'the open bottle names who opened it');
select is((pg_temp.detail('00000000-0000-4000-8000-000000000d62') -> 'product' ->> 'open_count')::integer, 1, 'and the product counts it');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000d64') -> 'product', 'null'::jsonb, 'an archived product has no detail');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000d63') -> 'product', 'null'::jsonb, 'another clinic''s product has no detail');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000d33');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000d61') -> 'product', 'null'::jsonb, 'Smile Dental''s product is hidden from Other Dental');
select is(jsonb_array_length(pg_temp.detail('00000000-0000-4000-8000-000000000d61') -> 'history'), 0, 'and so is its history');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000d34');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000d61') -> 'product', 'null'::jsonb, 'a stranger sees nothing');
reset role;

select * from finish();
rollback;
