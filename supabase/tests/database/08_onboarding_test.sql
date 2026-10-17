-- MS-111 · clinic_create and invite_members.
begin;
select plan(32);

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

-- Signed out: refused.
set local role anon;
select throws_ok($$ select public.clinic_create('Smile', 'Toronto', 'CA', 'America/Toronto', 'Sarah') $$, '42501', 'Sign in first',
  'anonymous callers cannot create a clinic');
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
select is((select count(*)::integer from public.clinics), 1, 'no second clinic was created');
select is((select count(*)::integer from public.memberships where user_id = '00000000-0000-4000-8000-000000000a11'), 1, 'no second membership either');

-- Invitations.
select throws_ok($$ select public.invite_members(pg_temp.clinic(), '{"email":"x"}') $$, '22023', 'Invitations must be a list', 'invites must be an array');
select throws_ok($$ select public.invite_members(pg_temp.clinic(), '[{"email":"not-an-email","role":"staff"}]') $$, '22023', 'Enter a valid email',
  'an invalid address is refused');
select throws_ok($$ select public.invite_members(pg_temp.clinic(), '[{"email":"a@dentory.test","role":"owner"}]') $$, '22023', 'Role must be Staff or Admin',
  'an unknown role is refused');
select is(public.invite_members(pg_temp.clinic(), '[{"email":"Priya@Dentory.test","role":"staff"},{"email":"kim@dentory.test","role":"admin"},{"email":"owner@dentory.test","role":"staff"}]'), 2,
  'two invitations are recorded; the owner, already active, is skipped');
select results_eq($$ select email, role::text, status::text, invited_by from public.memberships where clinic_id = pg_temp.clinic() and status = 'invited' order by email $$,
  $$ values ('kim@dentory.test', 'admin', 'invited', '00000000-0000-4000-8000-000000000a11'::uuid), ('priya@dentory.test', 'staff', 'invited', '00000000-0000-4000-8000-000000000a11'::uuid) $$,
  'invited rows carry the lower-cased address, the role and who invited');
select ok((select bool_and(invite_expires_at between now() + interval '6 days' and now() + interval '8 days') from public.memberships where clinic_id = pg_temp.clinic() and status = 'invited'),
  'invitations expire in 7 days');
select is(public.invite_members(pg_temp.clinic(), '[{"email":"priya@dentory.test","role":"admin"}]'), 1, 'inviting again refreshes the row');
select is((select role::text from public.memberships where clinic_id = pg_temp.clinic() and email = 'priya@dentory.test'), 'admin', 'the refreshed invitation carries the new role');
reset role;

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
select is((select count(*)::integer from public.clinics), 1, 'still one clinic');
select pg_temp.act_as('00000000-0000-4000-8000-000000000a12');
select is(public.membership_state(), 'none', 'a stranger with no rows is new');
reset role;

-- Someone who is not an admin of the clinic cannot invite.
select pg_temp.act_as('00000000-0000-4000-8000-000000000a12');
select throws_ok($$ select public.invite_members(pg_temp.clinic(), '[{"email":"z@dentory.test","role":"staff"}]') $$, '42501', 'Only an admin can invite',
  'a stranger cannot invite into the clinic');
reset role;

select * from finish();
rollback;
