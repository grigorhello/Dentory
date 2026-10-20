-- MS-133 · activity_alerts, alerts_mark_seen and alerts_unseen: the open alerts one row per subject, newest first,
-- with what each sentence needs; a delivery for admins only; clinic-isolated; the seen marker and the bell dot it
-- drives, over the same alerts the list shows; and an alert that clears once its condition is gone.
begin;
select plan(24);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000000a31', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000000a32', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000000a33', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-000000000a41', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', '{30,60,90}'),
  ('00000000-0000-4000-8000-000000000a42', 'Other Dental', 'CA', 'CAD', 'America/Toronto', '{90}');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000000a41', '00000000-0000-4000-8000-000000000a31', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000000a41', '00000000-0000-4000-8000-000000000a32', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000000a42', '00000000-0000-4000-8000-000000000a33', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target) values
  ('00000000-0000-4000-8000-000000000a61', '00000000-0000-4000-8000-000000000a41', 'Rubber dam latex-free', 'sheets', 'countable', 10, 36),
  ('00000000-0000-4000-8000-000000000a62', '00000000-0000-4000-8000-000000000a41', 'Endo file kit #15-40', 'kits', 'countable', 3, 5),
  ('00000000-0000-4000-8000-000000000a63', '00000000-0000-4000-8000-000000000a41', 'Bonding agent', 'bottles', 'multi_use', 0, 3),
  ('00000000-0000-4000-8000-000000000a64', '00000000-0000-4000-8000-000000000a41', 'Septocaine 4% 1:100,000', 'cartridges', 'countable', 20, 60),
  ('00000000-0000-4000-8000-000000000a65', '00000000-0000-4000-8000-000000000a41', 'Gutta percha F2', 'packs', 'countable', 3, 9),
  ('00000000-0000-4000-8000-000000000a66', '00000000-0000-4000-8000-000000000a42', 'Other clinic product', 'packs', 'countable', 5, 10);
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target, archived_at) values
  ('00000000-0000-4000-8000-000000000a67', '00000000-0000-4000-8000-000000000a41', 'Old gauze', 'packs', 'countable', 5, 10, now());
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000000a71', '00000000-0000-4000-8000-000000000a41', '00000000-0000-4000-8000-000000000a62', date_trunc('month', current_date + interval '2 years')::date, null, 1),
  ('00000000-0000-4000-8000-000000000a72', '00000000-0000-4000-8000-000000000a41', '00000000-0000-4000-8000-000000000a63', date_trunc('month', current_date + interval '1 month')::date, 'BA7', 1),
  ('00000000-0000-4000-8000-000000000a73', '00000000-0000-4000-8000-000000000a41', '00000000-0000-4000-8000-000000000a64', date_trunc('month', current_date + interval '2 months')::date, 'B441', 34),
  ('00000000-0000-4000-8000-000000000a74', '00000000-0000-4000-8000-000000000a41', '00000000-0000-4000-8000-000000000a64', date_trunc('month', current_date + interval '2 months')::date, 'A112', 20),
  ('00000000-0000-4000-8000-000000000a75', '00000000-0000-4000-8000-000000000a41', '00000000-0000-4000-8000-000000000a65', null, null, 7);
insert into public.invoices (id, clinic_id, storage_path, source, status, supplier, created_by) values
  ('00000000-0000-4000-8000-000000000a81', '00000000-0000-4000-8000-000000000a41', 'invoices/a81.jpg', 'camera', 'ready', 'Patterson', '00000000-0000-4000-8000-000000000a31');
-- The open alerts, as the engine would have opened them: Bonding agent's batch crossed 90 days, then 60.
insert into public.alerts (id, clinic_id, kind, product_id, batch_id, invoice_id, threshold_days, opened_at, resolved_at) values
  ('00000000-0000-4000-8000-000000000a91', '00000000-0000-4000-8000-000000000a41', 'invoice_ready', null, null, '00000000-0000-4000-8000-000000000a81', null, now() - interval '10 minutes', null),
  ('00000000-0000-4000-8000-000000000a92', '00000000-0000-4000-8000-000000000a41', 'out_of_stock', '00000000-0000-4000-8000-000000000a61', null, null, null, now() - interval '1 hour', null),
  ('00000000-0000-4000-8000-000000000a93', '00000000-0000-4000-8000-000000000a41', 'expiring', '00000000-0000-4000-8000-000000000a63', '00000000-0000-4000-8000-000000000a72', null, 90, now() - interval '3 days', null),
  ('00000000-0000-4000-8000-000000000a94', '00000000-0000-4000-8000-000000000a41', 'expiring', '00000000-0000-4000-8000-000000000a63', '00000000-0000-4000-8000-000000000a72', null, 60, now() - interval '1 day', null),
  ('00000000-0000-4000-8000-000000000a95', '00000000-0000-4000-8000-000000000a41', 'missing_expiry', '00000000-0000-4000-8000-000000000a65', null, null, null, now() - interval '1 day 1 hour', null),
  ('00000000-0000-4000-8000-000000000a96', '00000000-0000-4000-8000-000000000a41', 'low', '00000000-0000-4000-8000-000000000a62', null, null, null, now() - interval '2 days', null),
  ('00000000-0000-4000-8000-000000000a97', '00000000-0000-4000-8000-000000000a41', 'expiring', '00000000-0000-4000-8000-000000000a64', '00000000-0000-4000-8000-000000000a73', null, 90, now() - interval '5 days', null),
  ('00000000-0000-4000-8000-000000000a98', '00000000-0000-4000-8000-000000000a41', 'expiring', '00000000-0000-4000-8000-000000000a64', '00000000-0000-4000-8000-000000000a74', null, 90, now() - interval '6 days', null),
  ('00000000-0000-4000-8000-000000000a99', '00000000-0000-4000-8000-000000000a41', 'low', '00000000-0000-4000-8000-000000000a64', null, null, null, now() - interval '7 days', now() - interval '1 day'),
  ('00000000-0000-4000-8000-000000000a9a', '00000000-0000-4000-8000-000000000a41', 'out_of_stock', '00000000-0000-4000-8000-000000000a67', null, null, null, now() - interval '2 hours', null),
  ('00000000-0000-4000-8000-000000000a9b', '00000000-0000-4000-8000-000000000a42', 'out_of_stock', '00000000-0000-4000-8000-000000000a66', null, null, null, now(), null);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.alerts() returns jsonb language sql as $$
  select public.activity_alerts('00000000-0000-4000-8000-000000000a41')
$$;
create function pg_temp.kinds() returns text[] language sql as $$
  select coalesce(array_agg((a ->> 'kind') || ':' || coalesce(a ->> 'name', a ->> 'supplier') order by ord), '{}')
  from jsonb_array_elements(pg_temp.alerts()) with ordinality as x(a, ord)
$$;
create function pg_temp.row_of(p_alert uuid) returns jsonb language sql as $$
  select a from jsonb_array_elements(pg_temp.alerts()) a where (a ->> 'id')::uuid = p_alert
$$;

select ok(not has_function_privilege('anon', 'public.activity_alerts(uuid)', 'execute'), 'anon cannot read alerts');
select ok(not has_function_privilege('anon', 'public.alerts_mark_seen(uuid)', 'execute'), 'nor mark them seen');
select ok(not has_function_privilege('anon', 'public.alerts_unseen(uuid)', 'execute'), 'nor ask about the dot');

select pg_temp.act_as('00000000-0000-4000-8000-000000000a31');
select is(pg_temp.kinds(), array[
  'invoice_ready:Patterson', 'out_of_stock:Rubber dam latex-free', 'expiring:Bonding agent',
  'missing_expiry:Gutta percha F2', 'low:Endo file kit #15-40', 'expiring:Septocaine 4% 1:100,000',
  'expiring:Septocaine 4% 1:100,000'],
  'the admin sees every open alert newest first; resolved ones and an archived product''s stay out');
select is(pg_temp.row_of('00000000-0000-4000-8000-000000000a94') ->> 'threshold_days', '60',
  'a batch that crossed two thresholds is listed once, by the latest');
select is(pg_temp.row_of('00000000-0000-4000-8000-000000000a93'), null, 'not by the earlier one');
select results_eq(
  $$ select r ->> 'unit', (r ->> 'quantity')::numeric, (r ->> 'minimum')::numeric, r ->> 'tracking'
     from (select pg_temp.row_of('00000000-0000-4000-8000-000000000a96') r) x $$,
  $$ values ('kits', 1::numeric, 3::numeric, 'countable') $$,
  'a low alert carries the unit, the stock and the minimum');
select results_eq(
  $$ select r ->> 'lot', (r ->> 'expiring_batches')::integer, r ->> 'expiry_month' is not null
     from (select pg_temp.row_of(id) r from (values ('00000000-0000-4000-8000-000000000a97'::uuid), ('00000000-0000-4000-8000-000000000a94'::uuid)) v(id)) x $$,
  $$ values ('B441', 2, true), ('BA7', 1, true) $$,
  'an expiring alert carries the lot, the month and how many of the product''s batches are expiring');
select is(pg_temp.row_of('00000000-0000-4000-8000-000000000a91') ->> 'invoice_id', '00000000-0000-4000-8000-000000000a81',
  'a delivery alert carries its invoice');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000a32');
select is(array_length(pg_temp.kinds(), 1), 6, 'Staff see the same alerts');
select is(pg_temp.row_of('00000000-0000-4000-8000-000000000a91'), null, 'but not the delivery waiting for review');
select ok(public.alerts_unseen('00000000-0000-4000-8000-000000000a41'), 'a member who never opened Alerts has a dot');
select ok((select public.alerts_mark_seen('00000000-0000-4000-8000-000000000a41')) between now() - interval '1 second' and now() + interval '1 second',
  'opening Alerts marks them seen now');
select ok(not public.alerts_unseen('00000000-0000-4000-8000-000000000a41'), 'and the dot is gone');
select lives_ok($$ select public.alerts_mark_seen('00000000-0000-4000-8000-000000000a41') $$, 'and again');
reset role;
select is((select count(*) from public.alert_reads where user_id = '00000000-0000-4000-8000-000000000a32')::integer, 1,
  'one marker per member');

-- Both members last opened Alerts half an hour ago. Since then only the delivery opened, and an alert of the archived
-- Old gauze: neither is on Staff's list, so neither lights Staff's bell.
insert into public.alert_reads (clinic_id, user_id, last_seen_at) values
  ('00000000-0000-4000-8000-000000000a41', '00000000-0000-4000-8000-000000000a31', now() - interval '30 minutes'),
  ('00000000-0000-4000-8000-000000000a41', '00000000-0000-4000-8000-000000000a32', now() - interval '30 minutes')
on conflict (clinic_id, user_id) do update set last_seen_at = excluded.last_seen_at;
update public.alerts set opened_at = now() - interval '1 minute' where id = '00000000-0000-4000-8000-000000000a9a';
select pg_temp.act_as('00000000-0000-4000-8000-000000000a32');
select ok(not public.alerts_unseen('00000000-0000-4000-8000-000000000a41'),
  'Staff get no dot from a delivery waiting for review or an archived product''s alert');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000000a31');
select ok(public.alerts_unseen('00000000-0000-4000-8000-000000000a41'), 'the admin gets one from the delivery');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000a33');
select is(pg_temp.alerts(), '[]'::jsonb, 'another clinic sees none of them');
select ok(not public.alerts_unseen('00000000-0000-4000-8000-000000000a41'), 'and gets no dot from them');
select throws_ok($$ select public.alerts_mark_seen('00000000-0000-4000-8000-000000000a41') $$, '42501', null::text,
  'nor marks them seen');
reset role;

-- Acceptance: receiving the out-of-stock product clears its alert.
select pg_temp.act_as('00000000-0000-4000-8000-000000000a31');
select lives_ok($$ select public.stock_receive('00000000-0000-4000-8000-000000000a41',
  jsonb_build_array(jsonb_build_object('product_id', '00000000-0000-4000-8000-000000000a61', 'qty', 36,
    'expiry_month', date_trunc('month', current_date + interval '2 years')::date)),
  '00000000-0000-4000-8000-000000000ab1') $$, 'the admin receives 36 sheets of rubber dam');
select is(pg_temp.row_of('00000000-0000-4000-8000-000000000a92'), null, 'its out-of-stock alert is gone on the next read');
select ok(not ('out_of_stock:Rubber dam latex-free' = any (pg_temp.kinds())), 'and nothing else stands in for it');
reset role;

select * from finish();
rollback;
