-- MS-128 · To buy: the list, auto-add from a procedure, quantities, Mark as ordered, Add item, removing a
-- suggestion, and receiving.
begin;
select plan(31);

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
-- Rubber dam out (0 of min 10), Endo kit low (1 of 3), Septocaine healthy (25 of 20), Gloves healthy (12 of 5),
-- Gauze low (2 of 4), Old gauze archived.
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target, supplier, archived_at) values
  ('00000000-0000-4000-8000-000000000e61', '00000000-0000-4000-8000-000000000e41', 'Rubber dam', 'sheets', 'countable', 10, 36, 'Henry Schein', null),
  ('00000000-0000-4000-8000-000000000e62', '00000000-0000-4000-8000-000000000e41', 'Endo kit', 'kits', 'countable', 3, 5, 'Patterson', null),
  ('00000000-0000-4000-8000-000000000e63', '00000000-0000-4000-8000-000000000e41', 'Septocaine', 'cartridges', 'countable', 20, 60, 'Patterson', null),
  ('00000000-0000-4000-8000-000000000e64', '00000000-0000-4000-8000-000000000e41', 'Gloves', 'boxes', 'countable', 5, 20, null, null),
  ('00000000-0000-4000-8000-000000000e65', '00000000-0000-4000-8000-000000000e41', 'Gauze', 'packs', 'countable', 4, 10, null, null),
  ('00000000-0000-4000-8000-000000000e66', '00000000-0000-4000-8000-000000000e41', 'Old gauze', 'packs', 'countable', 4, 10, null, now()),
  ('00000000-0000-4000-8000-000000000e67', '00000000-0000-4000-8000-000000000e42', 'Other clinic product', 'packs', 'countable', 1, 5, null, null);
insert into public.batches (clinic_id, product_id, expiry_month, qty)
select '00000000-0000-4000-8000-000000000e41', v.product_id::uuid, date_trunc('month', current_date + interval '10 months')::date, v.qty
from (values
  ('00000000-0000-4000-8000-000000000e62', 1), ('00000000-0000-4000-8000-000000000e63', 25),
  ('00000000-0000-4000-8000-000000000e64', 12), ('00000000-0000-4000-8000-000000000e65', 2)
) as v (product_id, qty);
insert into public.procedure_templates (id, clinic_id, name) values
  ('00000000-0000-4000-8000-000000000e71', '00000000-0000-4000-8000-000000000e41', 'Root canal');
select public.refresh_product(p.id) from public.products p where p.clinic_id = '00000000-0000-4000-8000-000000000e41';

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.use(p_product uuid, p_qty numeric) returns void language sql as $$
  select null::void from (select public.stock_procedure_start(
    '00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e71', 'Root canal',
    jsonb_build_array(jsonb_build_object('product_id', p_product, 'qty', p_qty)), '{}'::uuid[], gen_random_uuid())) s
$$;
create function pg_temp.line(p_product uuid) returns uuid language sql as $$
  select id from public.to_buy_items where product_id = p_product order by created_at desc, id limit 1
$$;

select ok(not has_function_privilege('anon', 'public.to_buy_list(uuid)', 'execute'), 'anon cannot read To buy');
select ok(not has_function_privilege('anon', 'public.to_buy_add(uuid, uuid)', 'execute'), 'nor add to it');
select ok(not has_function_privilege('anon', 'public.to_buy_mark_ordered(uuid, uuid[])', 'execute'), 'nor mark lines ordered');

select pg_temp.act_as('00000000-0000-4000-8000-000000000e32');
select results_eq(
  $$ select name, supplier, quantity, target, qty, source, status from public.to_buy_list('00000000-0000-4000-8000-000000000e41') $$,
  $$ values ('Rubber dam', 'Henry Schein', 0::numeric, 36::numeric, 36::numeric, 'auto', 'to_buy'),
            ('Endo kit', 'Patterson', 1::numeric, 5::numeric, 4::numeric, 'auto', 'to_buy'),
            ('Gauze', null, 2::numeric, 10::numeric, 8::numeric, 'auto', 'to_buy') $$,
  'Low and Out of stock products wait to be bought in catalog order with target − current, the supplier when known');

-- Acceptance: a procedure that makes Septocaine Low adds it, a second one updates it, Ordered freezes it.
select pg_temp.use('00000000-0000-4000-8000-000000000e63', 6);
select results_eq(
  $$ select qty, source::text, status::text from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000000e63' $$,
  $$ values (41::numeric, 'auto', 'to_buy') $$,
  'starting a procedure that leaves Septocaine at 19 of min 20 adds it with 60 − 19');
select pg_temp.use('00000000-0000-4000-8000-000000000e63', 2);
select is((select qty from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000000e63'), 43::numeric,
  'a second procedure updates the suggestion');

select lives_ok($$
  update public.to_buy_items set qty = 6, qty_edited = true where product_id = '00000000-0000-4000-8000-000000000e62'
$$, 'staff change a quantity');
select pg_temp.use('00000000-0000-4000-8000-000000000e62', 1);
select is((select qty from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000000e62'), 6::numeric,
  'a quantity someone changed no longer follows stock');

select throws_ok($$ select public.to_buy_mark_ordered('00000000-0000-4000-8000-000000000e41',
    array['00000000-0000-4000-8000-000000000e63']::uuid[]) $$,
  '42501', 'Only an admin can mark items as ordered', 'staff cannot mark lines ordered');
select throws_ok($$
  update public.to_buy_items set status = 'ordered', ordered_at = now() where product_id = '00000000-0000-4000-8000-000000000e63'
$$, '42501', null, 'nor move a line past "to buy" directly');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000e31');
select is(
  public.to_buy_mark_ordered('00000000-0000-4000-8000-000000000e41', array[
    pg_temp.line('00000000-0000-4000-8000-000000000e63'), pg_temp.line('00000000-0000-4000-8000-000000000e61'),
    '00000000-0000-4000-8000-0000000000ff']::uuid[]),
  2, 'the admin marks Septocaine and Rubber dam as ordered; an unknown id is ignored');
select results_eq(
  $$ select status::text, ordered_by, ordered_at is not null from public.to_buy_items
     where product_id = '00000000-0000-4000-8000-000000000e63' $$,
  $$ values ('ordered', '00000000-0000-4000-8000-000000000e31'::uuid, true) $$,
  'with today''s date and the admin''s name');
select pg_temp.use('00000000-0000-4000-8000-000000000e63', 1);
select results_eq(
  $$ select qty, status::text from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000000e63' $$,
  $$ values (43::numeric, 'ordered') $$,
  'an ordered line keeps its quantity and no new line is added while it waits');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000e32');
select results_eq(
  $$ select (r ->> 'qty')::numeric, (r ->> 'created')::boolean
     from (select public.to_buy_add('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e64') r) s $$,
  $$ values (8::numeric, true) $$,
  'Add item puts Gloves on the list with 20 − 12, as a line it created');
select results_eq(
  $$ select source::text, added_by, qty_edited from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000000e64' $$,
  $$ values ('manual', '00000000-0000-4000-8000-000000000e32'::uuid, false) $$,
  'as a manual line by Michael');
select results_eq(
  $$ select (r ->> 'id')::uuid, (r ->> 'created')::boolean
     from (select public.to_buy_add('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e64') r) s $$,
  $$ values (pg_temp.line('00000000-0000-4000-8000-000000000e64'), false) $$,
  'adding it again keeps the one line and says it was already there, so the app offers no Undo');
select throws_ok($$ select public.to_buy_add('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e66') $$,
  '22023', 'This product no longer exists.', 'an archived product cannot be added');
select throws_ok($$ select public.to_buy_add('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e67') $$,
  '22023', 'This product no longer exists.', 'nor another clinic''s');

-- Removing a suggestion while Gauze is still Low keeps it away until Gauze recovers and drops again.
select lives_ok($$ delete from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000000e65' $$,
  'staff remove the Gauze suggestion');
reset role;
select ok((select to_buy_dismissed from public.products where id = '00000000-0000-4000-8000-000000000e65'),
  'Gauze is marked as dismissed');
select public.refresh_product('00000000-0000-4000-8000-000000000e65');
select is((select count(*) from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000000e65'), 0::bigint,
  'the next refresh does not bring it back while Gauze is still Low');
select pg_temp.act_as('00000000-0000-4000-8000-000000000e31');
select lives_ok($$ select public.stock_receive('00000000-0000-4000-8000-000000000e41',
  '[{"product_id":"00000000-0000-4000-8000-000000000e65","qty":5}]', gen_random_uuid()) $$, 'five packs of Gauze arrive');
select ok(not (select to_buy_dismissed from public.products where id = '00000000-0000-4000-8000-000000000e65'),
  'above its minimum again, Gauze is forgiven');
select lives_ok($$ select public.stock_adjust('00000000-0000-4000-8000-000000000e65', 1, 'Damaged', null, gen_random_uuid()) $$,
  'and drops to 1');
select results_eq(
  $$ select qty, source::text from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000000e65' and status = 'to_buy' $$,
  $$ values (9::numeric, 'auto') $$,
  'so it is suggested again with 10 − 1');

-- Receiving moves the ordered Rubber dam line to Received with the date.
select lives_ok($$ select public.stock_receive('00000000-0000-4000-8000-000000000e41',
  '[{"product_id":"00000000-0000-4000-8000-000000000e61","qty":36}]', gen_random_uuid()) $$, 'the Rubber dam arrives');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000e32');
select results_eq(
  $$ select name, status, qty, received_at is not null from public.to_buy_list('00000000-0000-4000-8000-000000000e41') $$,
  $$ values ('Endo kit', 'to_buy', 6::numeric, false), ('Gloves', 'to_buy', 8::numeric, false),
            ('Gauze', 'to_buy', 9::numeric, false), ('Septocaine', 'ordered', 43::numeric, false),
            ('Rubber dam', 'received', 36::numeric, true) $$,
  'the list reads To buy, then Ordered, then Received');
reset role;
update public.to_buy_items set received_at = now() - interval '91 days'
where product_id = '00000000-0000-4000-8000-000000000e61';
select pg_temp.act_as('00000000-0000-4000-8000-000000000e32');
select is((select count(*) from public.to_buy_list('00000000-0000-4000-8000-000000000e41') where status = 'received'),
  0::bigint, 'Received keeps the last 90 days');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000e33');
select is_empty($$ select * from public.to_buy_list('00000000-0000-4000-8000-000000000e41') $$,
  'another clinic sees nothing of Smile Dental''s list');
reset role;

update public.clinics set subscription_status = 'read_only' where id = '00000000-0000-4000-8000-000000000e41';
select pg_temp.act_as('00000000-0000-4000-8000-000000000e32');
select throws_ok($$ select public.to_buy_add('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e63') $$,
  '42501', 'The clinic is read-only until a payment method is added', 'a read-only clinic cannot add');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000000e31');
select throws_ok($$ select public.to_buy_mark_ordered('00000000-0000-4000-8000-000000000e41',
    array[pg_temp.line('00000000-0000-4000-8000-000000000e62')]::uuid[]) $$,
  '42501', 'The clinic is read-only until a payment method is added', 'nor mark lines ordered');
reset role;

select * from finish();
rollback;
