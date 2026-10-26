-- MS-126 · receive_overview: Receive delivery's lists for an admin only (Staff and other clinics refused), the
-- invoices still being read, ready to review or whose reading failed (the MS-129 fix, 42_receive_overview_failed_test),
-- newest first, and the lines marked Ordered, in To buy's Ordered order.
begin;
select plan(13);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000034201', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000034202', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000034203', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone) values
  ('00000000-0000-4000-8000-000000034211', 'Smile Dental', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-000000034212', 'Other Dental', 'CA', 'CAD', 'America/Toronto');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000034211', '00000000-0000-4000-8000-000000034201', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000034211', '00000000-0000-4000-8000-000000034202', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000034212', '00000000-0000-4000-8000-000000034203', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
insert into public.products (id, clinic_id, name, unit, supplier, archived_at) values
  ('00000000-0000-4000-8000-000000034221', '00000000-0000-4000-8000-000000034211', 'Needle 27g short', 'needles', 'Patterson', null),
  ('00000000-0000-4000-8000-000000034222', '00000000-0000-4000-8000-000000034211', 'Gauze', 'packs', 'Patterson', null),
  ('00000000-0000-4000-8000-000000034223', '00000000-0000-4000-8000-000000034211', 'Prophy angle', 'angles', null, null),
  ('00000000-0000-4000-8000-000000034224', '00000000-0000-4000-8000-000000034211', 'Composite A2', 'syringes', 'Patterson', null),
  ('00000000-0000-4000-8000-000000034225', '00000000-0000-4000-8000-000000034211', 'Alginate', 'bags', 'Patterson', null),
  ('00000000-0000-4000-8000-000000034226', '00000000-0000-4000-8000-000000034211', 'Old gauze', 'packs', 'Patterson', now()),
  ('00000000-0000-4000-8000-000000034227', '00000000-0000-4000-8000-000000034212', 'Other clinic product', 'packs', null, null);
-- Ordered yesterday: Needle and Gauze; three days ago: Prophy angle. Composite is still to buy, Alginate received,
-- Old gauze's product archived, and the other clinic has its own ordered line.
insert into public.to_buy_items (id, clinic_id, product_id, qty, status, ordered_at, received_at) values
  ('00000000-0000-4000-8000-000000034231', '00000000-0000-4000-8000-000000034211', '00000000-0000-4000-8000-000000034221', 60, 'ordered', now() - interval '1 day', null),
  ('00000000-0000-4000-8000-000000034232', '00000000-0000-4000-8000-000000034211', '00000000-0000-4000-8000-000000034222', 5, 'ordered', now() - interval '1 day', null),
  ('00000000-0000-4000-8000-000000034233', '00000000-0000-4000-8000-000000034211', '00000000-0000-4000-8000-000000034223', 70, 'ordered', now() - interval '3 days', null),
  ('00000000-0000-4000-8000-000000034234', '00000000-0000-4000-8000-000000034211', '00000000-0000-4000-8000-000000034224', 4, 'to_buy', null, null),
  ('00000000-0000-4000-8000-000000034235', '00000000-0000-4000-8000-000000034211', '00000000-0000-4000-8000-000000034225', 2, 'received', now() - interval '9 days', now() - interval '6 days'),
  ('00000000-0000-4000-8000-000000034236', '00000000-0000-4000-8000-000000034211', '00000000-0000-4000-8000-000000034226', 3, 'ordered', now() - interval '1 day', null),
  ('00000000-0000-4000-8000-000000034237', '00000000-0000-4000-8000-000000034212', '00000000-0000-4000-8000-000000034227', 1, 'ordered', now() - interval '1 day', null);
-- One invoice in each state, and the other clinic's ready one.
insert into public.invoices (id, clinic_id, storage_path, source, status, supplier, created_by, created_at) values
  ('00000000-0000-4000-8000-000000034241', '00000000-0000-4000-8000-000000034211', 'a/page-1.jpg', 'camera', 'ready', 'Patterson', '00000000-0000-4000-8000-000000034201', now() - interval '2 hours'),
  ('00000000-0000-4000-8000-000000034242', '00000000-0000-4000-8000-000000034211', 'b/page-1.pdf', 'file', 'reading', null, '00000000-0000-4000-8000-000000034201', now() - interval '5 minutes'),
  ('00000000-0000-4000-8000-000000034243', '00000000-0000-4000-8000-000000034211', 'c/page-1.jpg', 'camera', 'failed', null, '00000000-0000-4000-8000-000000034201', now() - interval '1 minute'),
  ('00000000-0000-4000-8000-000000034244', '00000000-0000-4000-8000-000000034211', 'd/page-1.jpg', 'camera', 'confirmed', 'Henry Schein', '00000000-0000-4000-8000-000000034201', now() - interval '1 day'),
  ('00000000-0000-4000-8000-000000034245', '00000000-0000-4000-8000-000000034211', 'e/page-1.jpg', 'camera', 'discarded', 'Benco', '00000000-0000-4000-8000-000000034201', now() - interval '1 day'),
  ('00000000-0000-4000-8000-000000034246', '00000000-0000-4000-8000-000000034212', 'f/page-1.jpg', 'camera', 'ready', 'Patterson', '00000000-0000-4000-8000-000000034203', now());
update public.invoices set confirmed_at = now(), confirmed_by = created_by where id = '00000000-0000-4000-8000-000000034244';

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

select ok(not has_function_privilege('anon', 'public.receive_overview(uuid)', 'execute'), 'anon cannot read it');
select ok(has_function_privilege('authenticated', 'public.receive_overview(uuid)', 'execute'), 'members can call it');

-- Staff: no entry point in the app, and the call itself is refused.
select pg_temp.act_as('00000000-0000-4000-8000-000000034202');
select throws_ok($$ select public.receive_overview('00000000-0000-4000-8000-000000034211') $$,
  '42501', 'Only an admin can receive deliveries', 'Staff are refused');
reset role;

-- Another clinic's admin is refused too.
select pg_temp.act_as('00000000-0000-4000-8000-000000034203');
select throws_ok($$ select public.receive_overview('00000000-0000-4000-8000-000000034211') $$,
  '42501', 'Only an admin can receive deliveries', 'an admin of another clinic is refused');
select is(jsonb_array_length(public.receive_overview('00000000-0000-4000-8000-000000034212') -> 'invoices'), 1,
  'and sees only their own clinic''s invoice');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000034201');
select is(
  (select array_agg(i ->> 'id' order by n) from jsonb_array_elements(public.receive_overview('00000000-0000-4000-8000-000000034211') -> 'invoices') with ordinality x(i, n)),
  array['00000000-0000-4000-8000-000000034243', '00000000-0000-4000-8000-000000034242', '00000000-0000-4000-8000-000000034241'],
  'Continue reviewing lists the invoice whose reading failed, the one being read and the one ready to review, newest first; confirmed and discarded ones stay out');
select results_eq(
  $$ select i ->> 'status', i ->> 'supplier', (i ->> 'created_at')::timestamptz
     from jsonb_array_elements(public.receive_overview('00000000-0000-4000-8000-000000034211') -> 'invoices') i $$,
  $$ select status::text, supplier, created_at from public.invoices
     where id in ('00000000-0000-4000-8000-000000034243', '00000000-0000-4000-8000-000000034242', '00000000-0000-4000-8000-000000034241')
     order by created_at desc $$,
  'each invoice carries its state, its supplier once read (null while reading) and when it was added');
select is(
  (select array_agg(w ->> 'name' order by n) from jsonb_array_elements(public.receive_overview('00000000-0000-4000-8000-000000034211') -> 'waiting') with ordinality x(w, n)),
  array['Gauze', 'Needle 27g short', 'Prophy angle'],
  'Waiting for delivery lists the ordered lines, newest order first, then by name; to buy, received and archived ones stay out');
select results_eq(
  $$ select (w ->> 'id')::uuid, (w ->> 'product_id')::uuid, w ->> 'unit', w ->> 'supplier', (w ->> 'qty')::numeric,
            (w ->> 'ordered_at')::timestamptz
     from jsonb_array_elements(public.receive_overview('00000000-0000-4000-8000-000000034211') -> 'waiting') w $$,
  $$ select t.id, t.product_id, p.unit, p.supplier, t.qty, t.ordered_at
     from public.to_buy_items t join public.products p on p.id = t.product_id
     where t.id in ('00000000-0000-4000-8000-000000034232', '00000000-0000-4000-8000-000000034231', '00000000-0000-4000-8000-000000034233')
     order by t.ordered_at desc, lower(p.name) $$,
  'each line carries the To buy line, its product, unit, supplier (null when unknown), quantity and order time');
reset role;

-- Nothing to list: both lists are empty arrays, never null.
delete from public.invoices where clinic_id = '00000000-0000-4000-8000-000000034211';
delete from public.to_buy_items where clinic_id = '00000000-0000-4000-8000-000000034211';
select pg_temp.act_as('00000000-0000-4000-8000-000000034201');
select is(public.receive_overview('00000000-0000-4000-8000-000000034211') -> 'invoices', '[]'::jsonb, 'no invoice to continue');
select is(public.receive_overview('00000000-0000-4000-8000-000000034211') -> 'waiting', '[]'::jsonb, 'nothing waiting');
reset role;

-- A read-only clinic's admin still reads it (the app keeps them off the screen, MS-142).
update public.clinics set trial_ends_at = now() - interval '1 day' where id = '00000000-0000-4000-8000-000000034211';
select pg_temp.act_as('00000000-0000-4000-8000-000000034201');
select ok(not public.clinic_can_write('00000000-0000-4000-8000-000000034211'), 'the clinic is read-only');
select lives_ok($$ select public.receive_overview('00000000-0000-4000-8000-000000034211') $$, 'and its admin can still read');
reset role;

select * from finish();
rollback;
