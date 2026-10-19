-- MS-112 · invitation_create, invitation_lookup, auth_user_id_for_email and invitation_accept.
begin;
select plan(66);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000000b21', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner@dentory.test'),
  ('00000000-0000-4000-8000-000000000b22', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'stranger@dentory.test'),
  ('00000000-0000-4000-8000-000000000b24', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'other@dentory.test');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

-- Grants: the token functions belong to the Edge Functions; the lookup is open to the signed-out app.
select ok(not has_function_privilege('anon', 'public.invitation_create(uuid, text, text, text, uuid)', 'execute'),
  'anon cannot create invitations');
select ok(not has_function_privilege('authenticated', 'public.invitation_create(uuid, text, text, text, uuid)', 'execute'),
  'a signed-in user cannot create invitations directly: the token must only travel by email');
select ok(not has_function_privilege('anon', 'public.invitation_accept(text, uuid, text)', 'execute'), 'anon cannot accept');
select ok(not has_function_privilege('authenticated', 'public.invitation_accept(text, uuid, text)', 'execute'), 'a signed-in user cannot accept directly');
select ok(not has_function_privilege('anon', 'public.auth_user_id_for_email(text)', 'execute'), 'anon cannot look up accounts by address');
select ok(not has_function_privilege('authenticated', 'public.invitation_check(text, uuid)', 'execute'), 'a signed-in user cannot run the check directly');
select ok(has_function_privilege('service_role', 'public.invitation_check(text, uuid)', 'execute'), 'service_role runs the check');
select ok(has_function_privilege('anon', 'public.invitation_lookup(text)', 'execute'), 'anon can read an invitation by its token');
select ok(has_function_privilege('service_role', 'public.invitation_create(uuid, text, text, text, uuid)', 'execute'), 'service_role creates');
select ok(has_function_privilege('service_role', 'public.invitation_accept(text, uuid, text)', 'execute'), 'service_role accepts');
select ok(not exists (select 1 from pg_proc where proname = 'invite_members'), 'invite_members is gone: invitation_create is the one door');

-- Two clinics: Smile Dental (owner b21) and Other Dental (owner b24).
select pg_temp.act_as('00000000-0000-4000-8000-000000000b21');
select lives_ok($$ select public.clinic_create('Smile Dental', 'Toronto', 'CA', 'America/Toronto', 'Dr. Sarah Mitchell') $$, 'the owner creates Smile Dental');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000000b24');
select lives_ok($$ select public.clinic_create('Other Dental', 'Ottawa', 'CA', 'America/Toronto', 'Dr. Other') $$, 'another owner creates Other Dental');
reset role;
create temp table inv_ids as
  select
    (select clinic_id from public.memberships where user_id = '00000000-0000-4000-8000-000000000b21' and status = 'active') as smile,
    (select clinic_id from public.memberships where user_id = '00000000-0000-4000-8000-000000000b24' and status = 'active') as other;
create function pg_temp.smile() returns uuid language sql security definer as $$ select smile from inv_ids $$;
create function pg_temp.other() returns uuid language sql security definer as $$ select other from inv_ids $$;

-- Refusals before any row is written.
select throws_ok($$ select * from public.invitation_create(pg_temp.smile(), 'priya@dentory.test', 'staff', '', null) $$, '42501',
  'Only an admin can invite', 'no inviter, no invitation');
select throws_ok($$ select * from public.invitation_create(pg_temp.smile(), 'priya@dentory.test', 'staff', '', '00000000-0000-4000-8000-000000000b22') $$, '42501',
  'Only an admin can invite', 'a stranger cannot invite into the clinic');
select throws_ok($$ select * from public.invitation_create(pg_temp.smile(), 'priya@dentory.test', 'staff', '', '00000000-0000-4000-8000-000000000b24') $$, '42501',
  'Only an admin can invite', 'the admin of another clinic cannot invite into this one');
select throws_ok($$ select * from public.invitation_create(pg_temp.smile(), 'not-an-email', 'staff', '', '00000000-0000-4000-8000-000000000b21') $$, '22023',
  'Enter a valid email', 'an invalid address is refused');
select throws_ok($$ select * from public.invitation_create(pg_temp.smile(), 'priya@dentory.test', 'owner', '', '00000000-0000-4000-8000-000000000b21') $$, '22023',
  'Role must be Staff or Admin', 'an unknown role is refused');
select throws_ok($$ select * from public.invitation_create(pg_temp.smile(), 'owner@dentory.test', 'staff', '', '00000000-0000-4000-8000-000000000b21') $$, '23505',
  'owner@dentory.test is already on the team', 'an active member cannot be invited again');
select is((select count(*)::integer from public.memberships where clinic_id = pg_temp.smile()), 1, 'nothing was written by the refusals');

-- The read-only clinic (trial over, no payment) cannot invite.
update public.clinics set trial_ends_at = now() - interval '1 day' where id = pg_temp.smile();
select throws_ok($$ select * from public.invitation_create(pg_temp.smile(), 'priya@dentory.test', 'staff', '', '00000000-0000-4000-8000-000000000b21') $$, '42501',
  'The clinic is read-only until a payment method is added', 'a read-only clinic cannot invite');
update public.clinics set trial_ends_at = now() + interval '90 days' where id = pg_temp.smile();

-- The invitation: a token that only the email carries, a hash in the row.
create temp table inv_tokens (name text primary key, token text);
grant select on inv_tokens to anon, authenticated;
insert into inv_tokens select 'priya1', token
  from public.invitation_create(pg_temp.smile(), ' Priya@Dentory.test ', 'staff', 'Priya Patel', '00000000-0000-4000-8000-000000000b21');
select ok((select token ~ '^[A-Za-z0-9_-]{40,}$' from inv_tokens where name = 'priya1'), 'the token is URL-safe and at least 40 characters');
select results_eq(
  $$ select email, full_name, role::text, status::text, invited_by, invite_token_hash from public.memberships where clinic_id = pg_temp.smile() and status = 'invited' $$,
  $$ select 'priya@dentory.test', 'Priya Patel', 'staff', 'invited', '00000000-0000-4000-8000-000000000b21'::uuid,
       encode(extensions.digest((select token from inv_tokens where name = 'priya1'), 'sha256'), 'hex') $$,
  'the row carries the lower-cased address, the name, the role, the inviter and the SHA-256 of the token, not the token');
select ok((select invite_expires_at between now() + interval '6 days 23 hours' and now() + interval '7 days 1 hour'
           from public.memberships where clinic_id = pg_temp.smile() and email = 'priya@dentory.test'),
  'the invitation expires in 7 days');

-- The lookup behind the Join screen.
set local role anon;
select results_eq(
  $$ select clinic_name, invited_by_name, member_role, email, full_name from public.invitation_lookup((select token from inv_tokens where name = 'priya1')) $$,
  $$ values ('Smile Dental', 'Dr. Sarah Mitchell', 'staff', 'priya@dentory.test', 'Priya Patel') $$,
  'the signed-out app reads the clinic, who invited, the role, the address and the name from the token');
select is((select count(*)::integer from public.invitation_lookup('not-the-token-at-all-not-the-token-at-all')), 0, 'a wrong token finds nothing');
select is((select count(*)::integer from public.invitation_lookup(null)), 0, 'a null token finds nothing');
select is((select count(*)::integer from public.invitation_lookup('short')), 0, 'a short token finds nothing');
reset role;

-- Resend: a new token; the old one stops working; the role follows; a blank name keeps the stored one.
insert into inv_tokens select 'priya2', token
  from public.invitation_create(pg_temp.smile(), 'priya@dentory.test', 'admin', '', '00000000-0000-4000-8000-000000000b21');
select isnt((select token from inv_tokens where name = 'priya2'), (select token from inv_tokens where name = 'priya1'), 'a resend issues a new token');
select is((select count(*)::integer from public.invitation_lookup((select token from inv_tokens where name = 'priya1'))), 0, 'the old token stops working');
select results_eq(
  $$ select member_role, full_name from public.invitation_lookup((select token from inv_tokens where name = 'priya2')) $$,
  $$ values ('admin', 'Priya Patel') $$, 'the new token carries the new role and keeps the name');
select is((select count(*)::integer from public.memberships where clinic_id = pg_temp.smile() and email = 'priya@dentory.test'), 1, 'still one row for the address');

-- Expiry: an invitation older than 7 days is rejected by the lookup and by accept.
update public.memberships set invite_expires_at = now() - interval '1 minute' where clinic_id = pg_temp.smile() and email = 'priya@dentory.test';
select is((select count(*)::integer from public.invitation_lookup((select token from inv_tokens where name = 'priya2'))), 0, 'an expired token finds nothing');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000000b25', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'priya@dentory.test');
select throws_ok($$ select public.invitation_accept((select token from inv_tokens where name = 'priya2'), '00000000-0000-4000-8000-000000000b25', 'Priya') $$, '22023',
  'This invitation has expired. Ask your admin to resend.', 'an expired token cannot be accepted');
update public.memberships set invite_expires_at = now() + interval '6 days' where clinic_id = pg_temp.smile() and email = 'priya@dentory.test';

-- Accounts behind an address.
select is(public.auth_user_id_for_email('PRIYA@dentory.test '), '00000000-0000-4000-8000-000000000b25'::uuid, 'the account lookup ignores case and spaces');
select is(public.auth_user_id_for_email('nobody@dentory.test'), null, 'an unknown address has no account');

-- Accept refusals.
select throws_ok($$ select public.invitation_accept((select token from inv_tokens where name = 'priya2'), null, 'Priya') $$, '42501',
  'Sign in first', 'accept needs a user');
select throws_ok($$ select public.invitation_accept('not-the-token-at-all-not-the-token-at-all', '00000000-0000-4000-8000-000000000b25', 'Priya') $$, '22023',
  'This invitation has expired. Ask your admin to resend.', 'a wrong token reads as expired');
select throws_ok($$ select public.invitation_accept((select token from inv_tokens where name = 'priya2'), '00000000-0000-4000-8000-000000000b22', 'Priya') $$, '42501',
  'This invitation was sent to another address', 'an account with another address cannot take the invitation');
select is((select status::text from public.memberships where clinic_id = pg_temp.smile() and email = 'priya@dentory.test'), 'invited', 'the refusals left the row invited');

-- The read-only check answers the same way, so accept_invitation can ask before changing a password.
select throws_ok($$ select public.invitation_check((select token from inv_tokens where name = 'priya2'), null) $$, '42501',
  'Sign in first', 'the check needs a user');
select throws_ok($$ select public.invitation_check('not-the-token-at-all-not-the-token-at-all', '00000000-0000-4000-8000-000000000b25') $$, '22023',
  'This invitation has expired. Ask your admin to resend.', 'the check reads a wrong token as expired');
select throws_ok($$ select public.invitation_check((select token from inv_tokens where name = 'priya2'), '00000000-0000-4000-8000-000000000b22') $$, '42501',
  'This invitation was sent to another address', 'the check refuses another address');
select is(public.invitation_check((select token from inv_tokens where name = 'priya2'), '00000000-0000-4000-8000-000000000b25'), pg_temp.smile(),
  'the check lets the invitee join');
select results_eq(
  $$ select status::text, user_id, invite_token_hash is not null from public.memberships where clinic_id = pg_temp.smile() and email = 'priya@dentory.test' $$,
  $$ values ('invited', null::uuid, true) $$, 'and changes nothing');

-- Accept: the row becomes the active membership, the token is consumed, the profile carries the name.
select is(public.invitation_accept((select token from inv_tokens where name = 'priya2'), '00000000-0000-4000-8000-000000000b25', ' Priya P. '), pg_temp.smile(),
  'accept returns the clinic');
select results_eq(
  $$ select user_id, status::text, role::text, full_name, invite_token_hash, invite_expires_at from public.memberships where clinic_id = pg_temp.smile() and email = 'priya@dentory.test' $$,
  $$ values ('00000000-0000-4000-8000-000000000b25'::uuid, 'active', 'admin', 'Priya P.', null::text, null::timestamptz) $$,
  'the membership is active for the user with the typed name and no token left');
select is((select full_name from public.profiles where user_id = '00000000-0000-4000-8000-000000000b25'), 'Priya P.', 'the profile carries the name');
select is((select count(*)::integer from public.invitation_lookup((select token from inv_tokens where name = 'priya2'))), 0, 'a used token finds nothing');
select throws_ok($$ select public.invitation_accept((select token from inv_tokens where name = 'priya2'), '00000000-0000-4000-8000-000000000b25', 'Priya') $$, '22023',
  'This invitation has expired. Ask your admin to resend.', 'a used token cannot be accepted twice');
select throws_ok($$ select public.invitation_check((select token from inv_tokens where name = 'priya2'), '00000000-0000-4000-8000-000000000b25') $$, '22023',
  'This invitation has expired. Ask your admin to resend.', 'the check reads a used token as expired');
select pg_temp.act_as('00000000-0000-4000-8000-000000000b25');
select is(public.membership_state(), 'active', 'the new member is active');
select is(public.current_role_in(pg_temp.smile()), 'admin', 'with the role of the latest invitation');
reset role;
select throws_ok($$ select * from public.invitation_create(pg_temp.smile(), 'priya@dentory.test', 'staff', '', '00000000-0000-4000-8000-000000000b21') $$, '23505',
  'priya@dentory.test is already on the team', 'an accepted member cannot be invited again');

-- A member of another clinic cannot take an invitation (one clinic per user in V1.1).
insert into inv_tokens select 'other', token
  from public.invitation_create(pg_temp.smile(), 'other@dentory.test', 'staff', 'Dr. Other', '00000000-0000-4000-8000-000000000b21');
select throws_ok($$ select public.invitation_check((select token from inv_tokens where name = 'other'), '00000000-0000-4000-8000-000000000b24') $$, '42501',
  'This account belongs to another clinic', 'the check refuses an active member of another clinic before anything changes');
select throws_ok($$ select public.invitation_accept((select token from inv_tokens where name = 'other'), '00000000-0000-4000-8000-000000000b24', 'Dr. Other') $$, '42501',
  'This account belongs to another clinic', 'an active member of another clinic cannot join');
select is((select status::text from public.memberships where clinic_id = pg_temp.smile() and email = 'other@dentory.test'), 'invited', 'the row stays invited');

-- A staff member cannot invite; a second admin can, and the email names them.
insert into inv_tokens select 'kim', token
  from public.invitation_create(pg_temp.smile(), 'kim@dentory.test', 'staff', '', '00000000-0000-4000-8000-000000000b25');
select results_eq(
  $$ select clinic_name, invited_by_name, member_role, full_name from public.invitation_lookup((select token from inv_tokens where name = 'kim')) $$,
  $$ values ('Smile Dental', 'Priya P.', 'staff', '') $$, 'the second admin invites under their own name');
update public.memberships set role = 'staff' where clinic_id = pg_temp.smile() and email = 'priya@dentory.test';
select throws_ok($$ select * from public.invitation_create(pg_temp.smile(), 'kim2@dentory.test', 'staff', '', '00000000-0000-4000-8000-000000000b25') $$, '42501',
  'Only an admin can invite', 'a staff member cannot invite');

-- A revoked member can be invited back and keeps the same account.
update public.memberships set status = 'revoked' where clinic_id = pg_temp.smile() and email = 'priya@dentory.test';
select pg_temp.act_as('00000000-0000-4000-8000-000000000b25');
select is(public.membership_state(), 'revoked', 'the revoked member is out');
reset role;
insert into inv_tokens select 'priya3', token
  from public.invitation_create(pg_temp.smile(), 'priya@dentory.test', 'staff', '', '00000000-0000-4000-8000-000000000b21');
select results_eq(
  $$ select status::text, user_id, full_name from public.memberships where clinic_id = pg_temp.smile() and email = 'priya@dentory.test' $$,
  $$ values ('invited', '00000000-0000-4000-8000-000000000b25'::uuid, 'Priya P.') $$, 'the revoked row is invited again');
select is(public.invitation_accept((select token from inv_tokens where name = 'priya3'), '00000000-0000-4000-8000-000000000b25', ''), pg_temp.smile(), 'the invitation is accepted again');
select pg_temp.act_as('00000000-0000-4000-8000-000000000b25');
select is(public.membership_state(), 'active', 'the member is back');
reset role;
select is((select full_name from public.memberships where clinic_id = pg_temp.smile() and email = 'priya@dentory.test'), 'Priya P.', 'a blank name on accept keeps the stored one');

-- Clinic isolation: a token of Smile Dental does not surface Other Dental.
select is((select clinic_name from public.invitation_lookup((select token from inv_tokens where name = 'other'))), 'Smile Dental', 'the lookup names the inviting clinic');
select is((select count(*)::integer from public.memberships where clinic_id = pg_temp.other()), 1, 'Other Dental has only its owner');

select * from finish();
rollback;
