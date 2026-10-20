-- MS-138 · Team: the list for every member in f31's order, the admin's role changes and removals, the last admin kept,
-- a removed member reading nothing, a read-only clinic, another clinic left alone.
begin;
select plan(27);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000015401', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000015402', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'daniel@dentory.test'),
  ('00000000-0000-4000-8000-000000015403', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000015404', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'gone@dentory.test'),
  ('00000000-0000-4000-8000-000000015405', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'solo@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone) values
  ('00000000-0000-4000-8000-000000015411', 'Smile Dental', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-000000015412', 'Solo Dental', 'CA', 'CAD', 'America/Toronto');
insert into public.profiles (user_id, full_name) values
  ('00000000-0000-4000-8000-000000015402', 'Dr. Daniel Kim');
insert into public.memberships (id, clinic_id, user_id, email, full_name, role, status, invited_at) values
  ('00000000-0000-4000-8000-000000015421', '00000000-0000-4000-8000-000000015411', '00000000-0000-4000-8000-000000015403', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active', now() - interval '80 days'),
  ('00000000-0000-4000-8000-000000015422', '00000000-0000-4000-8000-000000015411', '00000000-0000-4000-8000-000000015402', 'daniel@dentory.test', 'Daniel', 'admin', 'active', now() - interval '85 days'),
  ('00000000-0000-4000-8000-000000015423', '00000000-0000-4000-8000-000000015411', '00000000-0000-4000-8000-000000015401', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active', now() - interval '90 days'),
  ('00000000-0000-4000-8000-000000015424', '00000000-0000-4000-8000-000000015411', '00000000-0000-4000-8000-000000015404', 'gone@dentory.test', 'Gone Member', 'staff', 'revoked', now() - interval '70 days'),
  ('00000000-0000-4000-8000-000000015426', '00000000-0000-4000-8000-000000015412', '00000000-0000-4000-8000-000000015405', 'solo@dentory.test', 'Solo Admin', 'admin', 'active', now() - interval '30 days');
insert into public.memberships (id, clinic_id, email, full_name, role, status, invited_at, invite_token_hash, invite_expires_at) values
  ('00000000-0000-4000-8000-000000015425', '00000000-0000-4000-8000-000000015411', 'priya@dentory.test', '', 'staff', 'invited', now() - interval '1 day', 'hash', now() + interval '6 days');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

select ok(not has_function_privilege('anon', 'public.team_members(uuid)', 'execute'), 'anon cannot read a team');
select ok(not has_function_privilege('anon', 'public.team_remove(uuid)', 'execute'), 'anon cannot remove anyone');

-- Staff read the whole team, admins first, then Staff, then the open invitations.
select pg_temp.act_as('00000000-0000-4000-8000-000000015403');
select results_eq(
  $$select email, full_name, role::text, status::text from public.team_members('00000000-0000-4000-8000-000000015411')$$,
  $$values ('sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
           ('daniel@dentory.test', 'Dr. Daniel Kim', 'admin', 'active'),
           ('michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
           ('priya@dentory.test', '', 'staff', 'invited')$$,
  'Staff read the team in f31''s order, the profile''s name first, without the removed member'
);
select ok((select user_id is null and invited_at is not null from public.team_members('00000000-0000-4000-8000-000000015411')
  where status = 'invited'), 'an invitation has no account yet and the day it was sent');
select throws_ok(
  $$select public.team_set_role('00000000-0000-4000-8000-000000015425', 'admin')$$,
  '42501', 'Only an admin can change the team', 'Staff cannot change a role'
);
select throws_ok(
  $$select public.team_remove('00000000-0000-4000-8000-000000015425')$$,
  '42501', 'Only an admin can change the team', 'Staff cannot remove anyone'
);
reset role;

-- Another clinic's admin sees nothing of it and cannot touch it.
select pg_temp.act_as('00000000-0000-4000-8000-000000015405');
select is((select count(*)::integer from public.team_members('00000000-0000-4000-8000-000000015411')), 0,
  'another clinic reads none of the team');
select throws_ok(
  $$select public.team_remove('00000000-0000-4000-8000-000000015421')$$,
  '22023', 'This person is no longer on the team.', 'another clinic''s member cannot be found, let alone removed'
);
-- The only admin can neither step down nor leave.
select throws_ok(
  $$select public.team_set_role('00000000-0000-4000-8000-000000015426', 'staff')$$,
  '22023', 'A clinic needs at least one admin.', 'the last admin cannot be demoted'
);
select throws_ok(
  $$select public.team_remove('00000000-0000-4000-8000-000000015426')$$,
  '22023', 'A clinic needs at least one admin.', 'the last admin cannot be removed'
);
reset role;
select is((select role::text from public.memberships where id = '00000000-0000-4000-8000-000000015426'), 'admin',
  'the refused change left the role as it was');

-- The admin changes roles, both ways, an invitation's too.
select pg_temp.act_as('00000000-0000-4000-8000-000000015401');
select lives_ok($$select public.team_set_role('00000000-0000-4000-8000-000000015421', 'admin')$$, 'an admin makes Staff an admin');
select lives_ok($$select public.team_set_role('00000000-0000-4000-8000-000000015422', 'staff')$$, 'and an admin Staff');
select lives_ok($$select public.team_set_role('00000000-0000-4000-8000-000000015425', 'admin')$$,
  'and an invitation''s role before it is accepted');
reset role;
select results_eq(
  $$select id::text, role::text from public.memberships
    where id in ('00000000-0000-4000-8000-000000015421', '00000000-0000-4000-8000-000000015422', '00000000-0000-4000-8000-000000015425')
    order by id$$,
  $$values ('00000000-0000-4000-8000-000000015421', 'admin'), ('00000000-0000-4000-8000-000000015422', 'staff'),
           ('00000000-0000-4000-8000-000000015425', 'admin')$$,
  'the roles changed'
);

-- Removing a member keeps the row, revoked, and they read nothing afterwards; revoking an invitation kills its link.
select pg_temp.act_as('00000000-0000-4000-8000-000000015401');
select lives_ok($$select public.team_remove('00000000-0000-4000-8000-000000015422')$$, 'an admin removes a member');
select lives_ok($$select public.team_remove('00000000-0000-4000-8000-000000015425')$$, 'and revokes an invitation');
select results_eq(
  $$select email from public.team_members('00000000-0000-4000-8000-000000015411')$$,
  $$values ('sarah@dentory.test'), ('michael@dentory.test')$$,
  'neither is on the team any more'
);
select throws_ok(
  $$select public.team_remove('00000000-0000-4000-8000-000000015422')$$,
  '22023', 'This person is no longer on the team.', 'a removed member cannot be removed twice'
);
reset role;
select results_eq(
  $$select status::text, invite_token_hash is null and invite_expires_at is null from public.memberships
    where id in ('00000000-0000-4000-8000-000000015422', '00000000-0000-4000-8000-000000015425') order by id$$,
  $$values ('revoked', true), ('revoked', true)$$,
  'both rows stay, revoked, and the invitation has no link left'
);
select pg_temp.act_as('00000000-0000-4000-8000-000000015402');
select is((select count(*)::integer from public.team_members('00000000-0000-4000-8000-000000015411')), 0,
  'the removed member reads nothing of the clinic');
select is(public.membership_state(), 'revoked', 'and the app learns they were removed');
reset role;

-- An admin may step down while another admin remains; a read-only clinic changes nothing.
select pg_temp.act_as('00000000-0000-4000-8000-000000015401');
select lives_ok($$select public.team_set_role('00000000-0000-4000-8000-000000015423', 'staff')$$,
  'an admin steps down while another remains');
reset role;
update public.clinics set subscription_status = 'read_only' where id = '00000000-0000-4000-8000-000000015411';
select pg_temp.act_as('00000000-0000-4000-8000-000000015403');
select throws_ok(
  $$select public.team_set_role('00000000-0000-4000-8000-000000015423', 'admin')$$,
  '42501', 'The clinic is read-only until a payment method is added', 'a read-only clinic changes no role'
);
reset role;

-- An admin may also leave the clinic while another admin remains.
update public.clinics set subscription_status = 'trialing' where id = '00000000-0000-4000-8000-000000015411';
select pg_temp.act_as('00000000-0000-4000-8000-000000015403');
select lives_ok($$select public.team_set_role('00000000-0000-4000-8000-000000015423', 'admin')$$,
  'Sarah is an admin again');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000015401');
select lives_ok($$select public.team_remove('00000000-0000-4000-8000-000000015423')$$,
  'an admin leaves while another remains');
reset role;
select is((select status::text from public.memberships where id = '00000000-0000-4000-8000-000000015423'), 'revoked',
  'and her row is revoked');

select * from finish();
rollback;
