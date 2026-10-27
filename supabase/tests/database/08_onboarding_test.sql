-- MS-111 · clinic_create. (invite_members moved to invitation_create in MS-112: see 09_invitations_test.sql.)
begin;
select plan(23);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000000a11', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner@dentory.test'),
  ('00000000-0000-4000-8000-000000000a12', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'second@dentory.test'),
  ('00000000-0000-4000-8000-000000000a13', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'revoked@dentory.test');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

select is(public.currency_for_country('CA'), 'CAD', 'Canada pays in CAD');
select is(public.currency_for_country('us'), 'USD', 'country codes are case-insensitive');
select is(public.currency_for_country('FR'), 'EUR', 'euro countries pay in EUR');
select is(public.currency_for_country('ZZ'), 'USD', 'an unknown country falls back to USD');

-- Signed out: refused, by the grant itself since MS-151 (the function's own "Sign in first" stays for a missing user).
set local role anon;
select throws_ok($$ select public.clinic_create('Smile', 'Toronto', 'CA', 'America/Toronto', 'Sarah') $$, '42501',
  'permission denied for function clinic_create', 'anonymous callers cannot create a clinic');
reset role;

-- The owner creates the clinic.
select pg_temp.act_as('00000000-0000-4000-8000-000000000a11');
select is(public.membership_state(), 'none', 'a new user has no membership');
select throws_ok($$ select public.clinic_create('  ', 'Toronto', 'CA', 'America/Toronto', 'Sarah') $$, '22023', 'Enter the clinic name',
  'a blank name is refused');
select throws_ok($$ select public.clinic_create('Smile Dental', 'Toronto', 'C1', 'America/Toronto', 'Sarah') $$, '22023', 'Choose a country',
  'the country must be a two-letter code');
select lives_ok($$ select public.clinic_create('Smile Dental', 'Toronto', 'ca', 'America/Toronto', 'Dr. Sarah Mitchell') $$,
  'the owner creates the clinic');
reset role;
-- Read as the superuser, so the id is visible whoever acts next.
create temp table onboarding_ids as
  select clinic_id from public.memberships where user_id = '00000000-0000-4000-8000-000000000a11' and status = 'active' limit 1;
grant select on onboarding_ids to authenticated, anon;
create function pg_temp.clinic() returns uuid language sql security definer as $$ select clinic_id from onboarding_ids $$;
select pg_temp.act_as('00000000-0000-4000-8000-000000000a11');
select isnt(pg_temp.clinic(), null, 'the owner has an active membership');
select results_eq($$ select name, city, country, currency, time_zone, subscription_status::text from public.clinics where id = pg_temp.clinic() $$,
  $$ values ('Smile Dental', 'Toronto', 'CA'::char(2), 'CAD'::char(3), 'America/Toronto', 'trialing') $$,
  'the clinic carries the name, city, country, derived currency, time zone and a trial');
select ok((select trial_ends_at between now() + interval '89 days' and now() + interval '93 days' from public.clinics where id = pg_temp.clinic()),
  'the trial ends 3 months out');
select results_eq($$ select role::text, status::text, email, full_name from public.memberships where clinic_id = pg_temp.clinic() $$,
  $$ values ('admin', 'active', 'owner@dentory.test', 'Dr. Sarah Mitchell') $$, 'the owner is the active admin');
select is((select full_name from public.profiles where user_id = '00000000-0000-4000-8000-000000000a11'), 'Dr. Sarah Mitchell', 'the profile carries the name');
select results_eq($$ select name from public.categories where clinic_id = pg_temp.clinic() order by position $$,
  $$ values ('Anesthetic'), ('Restorative'), ('Endodontics'), ('Impression'), ('Preventive'), ('Surgical'), ('PPE'), ('Sterilization'), ('Disposable'), ('Other') $$,
  'the ten default categories exist in order (D13)');

-- Calling again returns the same clinic and creates nothing.
select is(public.clinic_create('Another Dental', 'Ottawa', 'CA', 'America/Toronto', 'Sarah'), pg_temp.clinic(), 'a second call returns the existing clinic');
select is((select count(*)::integer from public.clinics where name = 'Another Dental'), 0, 'no second clinic was created');
select is((select count(*)::integer from public.memberships where user_id = '00000000-0000-4000-8000-000000000a11'), 1, 'no second membership either');

-- The owner is active; a revoked member is neither active nor new.
select pg_temp.act_as('00000000-0000-4000-8000-000000000a11');
select is(public.membership_state(), 'active', 'the owner is active');
reset role;
insert into public.memberships (clinic_id, user_id, email, role, status)
values (pg_temp.clinic(), '00000000-0000-4000-8000-000000000a13', 'revoked@dentory.test', 'staff', 'revoked');
select pg_temp.act_as('00000000-0000-4000-8000-000000000a13');
select is(public.membership_state(), 'revoked', 'a revoked member reads as revoked, not as new');
select throws_ok($$ select public.clinic_create('Rogue Dental', 'Ottawa', 'CA', 'America/Toronto', 'Rogue') $$, '42501',
  'This account belongs to another clinic', 'a revoked member cannot found a new clinic');
reset role;
select is((select count(*)::integer from public.clinics where name = 'Rogue Dental'), 0, 'no rogue clinic was created');
select pg_temp.act_as('00000000-0000-4000-8000-000000000a12');
select is(public.membership_state(), 'none', 'a stranger with no rows is new');
reset role;

select * from finish();
rollback;
