-- MS-142 · Read-only mode: a clinic whose trial ended without a card refuses every direct write with the read-only
-- sentence, deletes included; reading, "seen" markers and push tokens stay open; the server's own writes pass, and a
-- card added through the webhook restores writes.
begin;
select plan(16);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000019401', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000019402', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, trial_ends_at) values
  ('00000000-0000-4000-8000-000000019411', 'Ended Dental', 'CA', 'CAD', 'America/Toronto', now() - interval '1 day'),
  ('00000000-0000-4000-8000-000000019412', 'Open Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000019411', '00000000-0000-4000-8000-000000019401', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000019411', '00000000-0000-4000-8000-000000019402', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000019412', '00000000-0000-4000-8000-000000019401', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active');
insert into public.categories (id, clinic_id, name) values
  ('00000000-0000-4000-8000-000000019421', '00000000-0000-4000-8000-000000019411', 'Anesthetic'),
  ('00000000-0000-4000-8000-000000019422', '00000000-0000-4000-8000-000000019412', 'Anesthetic');
insert into public.products (id, clinic_id, name, unit) values
  ('00000000-0000-4000-8000-000000019431', '00000000-0000-4000-8000-000000019411', 'Septocaine', 'cartridges');
insert into public.procedure_templates (id, clinic_id, name) values
  ('00000000-0000-4000-8000-000000019441', '00000000-0000-4000-8000-000000019411', 'Root canal');
insert into public.to_buy_items (id, clinic_id, product_id, qty) values
  ('00000000-0000-4000-8000-000000019451', '00000000-0000-4000-8000-000000019411', '00000000-0000-4000-8000-000000019431', 2);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

-- The admin of the read-only clinic.
select pg_temp.act_as('00000000-0000-4000-8000-000000019401');
select throws_ok($$update public.clinics set name = 'Renamed' where id = '00000000-0000-4000-8000-000000019411'$$,
  '42501', 'The clinic is read-only until a payment method is added', 'the clinic itself cannot change');
select throws_ok($$insert into public.categories (clinic_id, name) values ('00000000-0000-4000-8000-000000019411', 'Gloves')$$,
  '42501', 'The clinic is read-only until a payment method is added', 'nothing is added');
select throws_ok($$delete from public.categories where id = '00000000-0000-4000-8000-000000019421'$$,
  '42501', 'The clinic is read-only until a payment method is added', 'a delete is refused, not silently skipped');
select throws_ok($$update public.procedure_templates set name = 'Molar' where id = '00000000-0000-4000-8000-000000019441'$$,
  '42501', 'The clinic is read-only until a payment method is added', 'templates do not change');
select throws_ok($$delete from public.procedure_templates where id = '00000000-0000-4000-8000-000000019441'$$,
  '42501', 'The clinic is read-only until a payment method is added', 'nor are they deleted');
select lives_ok($$insert into public.categories (clinic_id, name) values ('00000000-0000-4000-8000-000000019412', 'Gloves')$$,
  'the same admin still writes in a clinic that may');
reset role;

-- Staff of the read-only clinic.
select pg_temp.act_as('00000000-0000-4000-8000-000000019402');
select throws_ok($$update public.to_buy_items set qty = 5 where id = '00000000-0000-4000-8000-000000019451'$$,
  '42501', 'The clinic is read-only until a payment method is added', 'a quantity to buy does not change');
select throws_ok($$delete from public.to_buy_items where id = '00000000-0000-4000-8000-000000019451'$$,
  '42501', 'The clinic is read-only until a payment method is added', 'a line to buy is not removed');
select throws_ok(
  $$insert into public.to_buy_items (clinic_id, product_id, qty) values
    ('00000000-0000-4000-8000-000000019411', '00000000-0000-4000-8000-000000019431', 1)$$,
  '42501', 'The clinic is read-only until a payment method is added', 'nor is one added');
select is((select count(*)::integer from public.to_buy_items where clinic_id = '00000000-0000-4000-8000-000000019411'), 1,
  'reading works as before');
select lives_ok(
  $$insert into public.alert_reads (clinic_id, user_id) values
    ('00000000-0000-4000-8000-000000019411', '00000000-0000-4000-8000-000000019402')$$,
  'a member still marks alerts seen');
select lives_ok(
  $$insert into public.push_tokens (user_id, token) values ('00000000-0000-4000-8000-000000019402', 'device-read-only')$$,
  'and registers a device for push');
reset role;

-- The server's own writes pass; the webhook's card restores writes.
select ok(not public.clinic_can_write('00000000-0000-4000-8000-000000019411'), 'the clinic is read-only');
set local role service_role;
select lives_ok($$update public.clinics set subscription_status = 'active' where id = '00000000-0000-4000-8000-000000019411'$$,
  'the billing webhook updates a read-only clinic');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000019402');
select lives_ok($$update public.to_buy_items set qty = 5 where id = '00000000-0000-4000-8000-000000019451'$$,
  'once a card is on file, writes work again');
reset role;
select is((select qty from public.to_buy_items where id = '00000000-0000-4000-8000-000000019451'), 5.00::numeric,
  'and the change is kept');

select * from finish();
rollback;
