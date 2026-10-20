-- MS-142 follow-up: in a read-only clinic an admin still removes a teammate or revokes an invitation, but cannot change
-- a role or put up a logo; a clinic that may write keeps doing all of it.
begin;
select plan(8);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000022401', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000022402', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000022403', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'priya@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, trial_ends_at) values
  ('00000000-0000-4000-8000-000000022411', 'Lapsed Dental', 'CA', 'CAD', 'America/Toronto', now() - interval '1 day'),
  ('00000000-0000-4000-8000-000000022412', 'Open Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days');
insert into public.memberships (id, clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000022421', '00000000-0000-4000-8000-000000022411', '00000000-0000-4000-8000-000000022401',
   'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000022422', '00000000-0000-4000-8000-000000022411', '00000000-0000-4000-8000-000000022402',
   'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000022423', '00000000-0000-4000-8000-000000022411', null,
   'ivy@dentory.test', 'Ivy Chen', 'staff', 'invited'),
  ('00000000-0000-4000-8000-000000022424', '00000000-0000-4000-8000-000000022412', '00000000-0000-4000-8000-000000022403',
   'priya@dentory.test', 'Priya Patel', 'admin', 'active');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

-- Staff of the read-only clinic cannot remove anyone, as before.
select pg_temp.act_as('00000000-0000-4000-8000-000000022402');
select throws_ok($$select public.team_remove('00000000-0000-4000-8000-000000022421')$$, '42501',
  'Only an admin can change the team', 'Staff cannot remove anyone');
reset role;

-- The read-only clinic's admin.
select pg_temp.act_as('00000000-0000-4000-8000-000000022401');
select throws_ok($$select public.team_set_role('00000000-0000-4000-8000-000000022422', 'admin')$$, '42501',
  'The clinic is read-only until a payment method is added', 'a role change waits for a payment method');
select lives_ok($$select public.team_remove('00000000-0000-4000-8000-000000022422')$$,
  'but the admin takes a teammate off the team');
select lives_ok($$select public.team_remove('00000000-0000-4000-8000-000000022423')$$, 'and revokes an invitation');
select throws_ok($$select public.team_remove('00000000-0000-4000-8000-000000022421')$$, '22023',
  'A clinic needs at least one admin.', 'the last admin stays');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('logos', '00000000-0000-4000-8000-000000022411/logo.png')$$,
  '42501', null, 'no new logo while read-only');
reset role;
select is(
  (select array_agg(status::text order by email) from public.memberships
   where clinic_id = '00000000-0000-4000-8000-000000022411'),
  array['revoked', 'revoked', 'active'], 'the invitation and the teammate are revoked, the admin kept');

-- An admin of a clinic that may write still puts up a logo.
select pg_temp.act_as('00000000-0000-4000-8000-000000022403');
select lives_ok(
  $$insert into storage.objects (bucket_id, name) values ('logos', '00000000-0000-4000-8000-000000022412/logo.png')$$,
  'a clinic that may write puts up its logo');
reset role;

select * from finish();
rollback;
