-- MS-119 · Add expiry and Edit batch through batch_upsert (MS-106), as Product detail and Home read them.
begin;
select plan(14);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000000c31', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000000c32', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000000c33', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-000000000c41', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', '{90}'),
  ('00000000-0000-4000-8000-000000000c42', 'Other Dental', 'CA', 'CAD', 'America/Toronto', '{90}');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c31', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c32', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000000c42', '00000000-0000-4000-8000-000000000c33', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target) values
  ('00000000-0000-4000-8000-000000000c61', '00000000-0000-4000-8000-000000000c41', 'Gutta percha F2', 'packs', 'countable', 3, 10),
  ('00000000-0000-4000-8000-000000000c62', '00000000-0000-4000-8000-000000000c41', 'Septocaine 4% 1:100,000', 'cartridges', 'countable', 10, 60);
-- Gutta percha: 7 packs with no expiry date. Septocaine: 20 dated eight months out.
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000000c71', '00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c61', null, null, 7),
  ('00000000-0000-4000-8000-000000000c72', '00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c62', date_trunc('month', current_date + interval '8 months')::date, 'A112', 20);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.status(p uuid) returns text language sql as $$
  select status from public.product_status where product_id = p
$$;
create function pg_temp.missing_tile() returns integer language sql as $$
  select missing_expiry_product_count from public.clinic_attention where clinic_id = '00000000-0000-4000-8000-000000000c41'
$$;
create function pg_temp.ledger(p uuid) returns setof text language sql as $$
  select trim_scale(t.delta)::text || ' ' || t.ref_label || ' · ' || t.reason from public.transactions t where t.product_id = p order by t.at
$$;

select pg_temp.act_as('00000000-0000-4000-8000-000000000c32');
select is(pg_temp.status('00000000-0000-4000-8000-000000000c61'), 'missing_expiry', 'Gutta percha starts as Missing expiry');
select is(pg_temp.missing_tile(), 1, 'and Home counts it on the Missing expiry tile');

-- Staff dates all of the undated stock: Missing expiry clears on the product and on Home.
select lives_ok(
  $$ select public.batch_upsert('00000000-0000-4000-8000-000000000c61', null,
       date_trunc('month', current_date + interval '10 months')::date, 7, 'GP7', gen_random_uuid()) $$,
  'staff adds an expiry to the 7 undated packs');
select is((select missing_expiry_qty from public.product_status where product_id = '00000000-0000-4000-8000-000000000c61'), 0::numeric,
  'no undated quantity is left');
select is(pg_temp.status('00000000-0000-4000-8000-000000000c61'), 'healthy', 'Missing expiry clears');
select is(pg_temp.missing_tile(), 0, 'and the Home tile drops to 0');
select is((select count(*) from public.transactions where product_id = '00000000-0000-4000-8000-000000000c61'), 0::bigint,
  'dating undated stock moves it without a ledger row');

-- Dating more than the undated stock: the extra is a Data correction.
select lives_ok(
  $$ select public.batch_upsert('00000000-0000-4000-8000-000000000c61', null,
       date_trunc('month', current_date + interval '11 months')::date, 3, null, gen_random_uuid()) $$,
  'adding expiry to 3 more than the undated stock');
select results_eq($$ select * from pg_temp.ledger('00000000-0000-4000-8000-000000000c61') $$,
  $$ values ('3 Add expiry · Data correction') $$, 'the 3 beyond the undated stock are a Data correction');

-- Edit batch: a lower quantity is a Data correction too; a past month reads as expired and Expiring.
select lives_ok(
  $$ select public.batch_upsert('00000000-0000-4000-8000-000000000c62', '00000000-0000-4000-8000-000000000c72',
       date_trunc('month', current_date - interval '1 month')::date, 18, 'A112', gen_random_uuid()) $$,
  'staff edits the batch: last month, 18');
select results_eq($$ select * from pg_temp.ledger('00000000-0000-4000-8000-000000000c62') $$,
  $$ values ('-2 Edit batch · Data correction') $$, 'the 2 fewer are a Data correction');
select is(pg_temp.status('00000000-0000-4000-8000-000000000c62'), 'expiring', 'a batch dated last month makes the product Expiring');
select throws_ok(
  $$ select public.batch_upsert('00000000-0000-4000-8000-000000000c62', null, '2027-03-15', 1, null, gen_random_uuid()) $$,
  '22023', 'the expiry is a month', 'an expiry is a month, never a day');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000c33');
select throws_ok(
  $$ select public.batch_upsert('00000000-0000-4000-8000-000000000c61', null, date_trunc('month', current_date)::date, 1, null, gen_random_uuid()) $$,
  '42501', 'not a member of this clinic', 'another clinic cannot add an expiry');
reset role;

select * from finish();
rollback;
