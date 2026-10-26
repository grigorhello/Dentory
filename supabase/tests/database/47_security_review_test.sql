-- MS-151 · The security review's fixes in the database (20261021130000_security_review.sql): an admin writes no
-- membership but its role, so a token the admin made up opens nothing (F1); clinic settings and billing emails change
-- only through their functions, and a new clinic keeps only a time zone Postgres knows (F2); Staff read no billing
-- column (F5); invitations stop at 30 an hour per clinic and 3 to one address (F6); the functions closed to anon stay
-- open to members (F8).
begin;
select plan(43);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-0000000047a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-0000000047a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dana@dentory.test'),
  ('00000000-0000-4000-8000-000000004751', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-0000000047b1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'lee@dentory.test'),
  ('00000000-0000-4000-8000-0000000047e1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mars@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone) values
  ('00000000-0000-4000-8000-0000000047c1', 'Smile Dental', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-0000000047c2', 'Other Dental', 'CA', 'CAD', 'America/Toronto');
insert into public.memberships (id, clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000004761', '00000000-0000-4000-8000-0000000047c1', '00000000-0000-4000-8000-0000000047a1',
   'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000004762', '00000000-0000-4000-8000-0000000047c1', '00000000-0000-4000-8000-0000000047a2',
   'dana@dentory.test', 'Dana Kim', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000004763', '00000000-0000-4000-8000-0000000047c1', '00000000-0000-4000-8000-000000004751',
   'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000004764', '00000000-0000-4000-8000-0000000047c2', '00000000-0000-4000-8000-0000000047b1',
   'lee@dentory.test', 'Lee Park', 'admin', 'active');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

-- F1 · An admin writes no membership but its role ------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-0000000047a1');
select throws_ok(
  $$insert into public.memberships (clinic_id, email, role, status, invite_token_hash, invite_expires_at)
    values ('00000000-0000-4000-8000-0000000047c1', 'priya@dentory.test', 'staff', 'invited',
            encode(extensions.digest('a-token-the-admin-made-up-0123456789', 'sha256'), 'hex'), now() + interval '1 day')$$,
  '42501', null, 'an admin cannot write an invitation with a token of their own');
select throws_ok(
  $$update public.memberships
    set status = 'invited', invite_expires_at = now() + interval '1 day',
        invite_token_hash = encode(extensions.digest('a-token-the-admin-made-up-0123456789', 'sha256'), 'hex')
    where id = '00000000-0000-4000-8000-000000004762'$$,
  '42501', null, 'nor turn a colleague back into an invitation they hold the token of');
select throws_ok(
  $$update public.memberships set user_id = '00000000-0000-4000-8000-0000000047b1'
    where id = '00000000-0000-4000-8000-000000004763'$$,
  '42501', null, 'nor give a seat to another account');
select throws_ok(
  $$update public.memberships set email = 'lee@dentory.test' where id = '00000000-0000-4000-8000-000000004763'$$,
  '42501', null, 'nor change the address an invitation goes to');
select throws_ok(
  $$delete from public.memberships where id = '00000000-0000-4000-8000-000000004763'$$,
  '42501', null, 'nor delete a member: removing keeps the row, revoked');
select lives_ok(
  $$update public.memberships set role = 'staff' where id = '00000000-0000-4000-8000-000000004762'$$,
  'the role stays writable, as team_set_role runs as the admin');
reset role;
select results_eq(
  $$select status::text, invite_token_hash from public.memberships where id = '00000000-0000-4000-8000-000000004762'$$,
  $$values ('active', null::text)$$,
  'the colleague''s membership is otherwise as it was');
select throws_ok(
  $$select public.invitation_check('a-token-the-admin-made-up-0123456789', '00000000-0000-4000-8000-0000000047a2')$$,
  '22023', 'This invitation has expired. Ask your admin to resend.',
  'so a token the admin made up opens nothing, and accept_invitation sets no password with it');

-- F2 · Clinic settings and billing emails change only through their functions ----------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-0000000047a1');
select throws_ok(
  format('update public.clinics set %I = %s where id = %L', setting.column_name, setting.value,
         '00000000-0000-4000-8000-0000000047c1'),
  '42501', null, 'an admin cannot write ' || setting.column_name || ' directly')
from (values
  ('name', $$'Renamed'$$), ('city', $$'Ottawa'$$), ('country', $$'US'$$), ('currency', $$'USD'$$),
  ('time_zone', $$'Mars/Olympus_Mons'$$), ('expiry_thresholds', $$'{90}'$$), ('email_digest', 'true'),
  ('billing_emails', $$'{someone@dentory.test}'$$)
) as setting (column_name, value);
select lives_ok(
  $$update public.clinics set logo_path = '00000000-0000-4000-8000-0000000047c1/logo.jpg'
    where id = '00000000-0000-4000-8000-0000000047c1'$$,
  'the logo''s path is written directly, as the app uploads it');
select lives_ok(
  $$select public.clinic_settings_save('00000000-0000-4000-8000-0000000047c1', 'Smile Dental Group', 'Toronto', 'CA',
    'CAD', 'America/Toronto', '{60,90}', true)$$,
  'and the settings through clinic_settings_save, with its checks');
reset role;

-- A time zone Postgres does not know, sent past the app, stopped the nightly refresh of every clinic once one of the
-- clinic's products ran out: the push of its out-of-stock alert works out the clinic's waking hours.
select pg_temp.act_as('00000000-0000-4000-8000-0000000047e1');
select lives_ok($$select public.clinic_create('Mars Dental', 'Olympus', 'CA', 'Mars/Olympus_Mons', 'Dr. Mars')$$,
  'a clinic made with a time zone Postgres does not know');
reset role;
select is(
  (select c.time_zone from public.clinics c
   join public.memberships m on m.clinic_id = c.id
   where m.user_id = '00000000-0000-4000-8000-0000000047e1'),
  'UTC', 'keeps UTC instead, for the admin to change in Clinic settings');
insert into public.products (clinic_id, name, unit)
select m.clinic_id, 'Gloves', 'boxes' from public.memberships m where m.user_id = '00000000-0000-4000-8000-0000000047e1';
select lives_ok($$select public.refresh_all_products()$$,
  'and the nightly refresh runs, the clinic''s product out of stock and its push queued included');

-- F5 · Staff read no billing column ---------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000004751');
select throws_ok(
  format('select %I from public.clinics', billing.column_name),
  '42501', null, 'Staff cannot read ' || billing.column_name)
from unnest(array['stripe_customer_id', 'stripe_subscription_id', 'promo_lifetime_50', 'billing_emails'])
  as billing (column_name);
select results_eq(
  $$select name, time_zone, expiry_thresholds, email_digest, subscription_status::text, logo_path from public.clinics$$,
  $$values ('Smile Dental Group', 'America/Toronto', '{60,90}'::integer[], true, 'trialing',
            '00000000-0000-4000-8000-0000000047c1/logo.jpg')$$,
  'but reads everything else the app shows of the clinic, and only their own clinic');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000000047a1');
select is(
  (select promo_lifetime_50 from public.billing_summary('00000000-0000-4000-8000-0000000047c1')), false,
  'an admin reads billing through billing_summary');
reset role;

-- F6 · 30 invitations an hour per clinic, 3 to one address ----------------------------------------------------------
select is(
  (select count(*)::integer
   from generate_series(1, 30) g,
        lateral public.invitation_create('00000000-0000-4000-8000-0000000047c1', 'guest' || g || '@dentory.test', 'staff',
                                         '', '00000000-0000-4000-8000-0000000047a1')),
  30, 'a clinic sends 30 invitations in an hour');
select throws_ok(
  $$select * from public.invitation_create('00000000-0000-4000-8000-0000000047c1', 'guest31@dentory.test', 'staff', '',
    '00000000-0000-4000-8000-0000000047a1')$$,
  '22023', 'Your clinic sent 30 invitations in the last hour. Try again in an hour.', 'and not a 31st');
select is(
  (select count(*)::integer from (
    select * from public.invitation_create('00000000-0000-4000-8000-0000000047c2', 'priya@dentory.test', 'staff', '',
                                           '00000000-0000-4000-8000-0000000047b1')
    union all
    select * from public.invitation_create('00000000-0000-4000-8000-0000000047c2', 'priya@dentory.test', 'staff', '',
                                           '00000000-0000-4000-8000-0000000047b1')
    union all
    select * from public.invitation_create('00000000-0000-4000-8000-0000000047c2', 'priya@dentory.test', 'staff', '',
                                           '00000000-0000-4000-8000-0000000047b1')
  ) sends),
  3, 'one address gets an invitation and 2 resends in an hour');
select throws_ok(
  $$select * from public.invitation_create('00000000-0000-4000-8000-0000000047c2', ' Priya@Dentory.test ', 'staff', '',
    '00000000-0000-4000-8000-0000000047b1')$$,
  '22023', 'This address got 3 invitations in the last hour. Try again in an hour.',
  'and not a third resend, however the address is written');
select is(
  (select count(*)::integer from public.invitation_sends
   where clinic_id = '00000000-0000-4000-8000-0000000047c2' and email = 'priya@dentory.test'),
  3, 'a refused invitation leaves no record');
select lives_ok(
  $$select * from public.invitation_create('00000000-0000-4000-8000-0000000047c2', 'kim@dentory.test', 'staff', '',
    '00000000-0000-4000-8000-0000000047b1')$$,
  'another address still gets one');
select is(
  (select count(*)::integer from public.memberships
   where clinic_id = '00000000-0000-4000-8000-0000000047c1' and email like 'guest%'),
  30, 'the first clinic''s 30 invitations stand');
update public.invitation_sends set sent_at = now() - interval '61 minutes'
where clinic_id = '00000000-0000-4000-8000-0000000047c1';
select lives_ok(
  $$select * from public.invitation_create('00000000-0000-4000-8000-0000000047c1', 'guest31@dentory.test', 'staff', '',
    '00000000-0000-4000-8000-0000000047a1')$$,
  'an hour later the clinic invites again');
select is(
  (select count(*)::integer from public.invitation_sends where clinic_id = '00000000-0000-4000-8000-0000000047c1'),
  1, 'and the invitations older than an hour are forgotten');
select ok(
  not has_table_privilege('authenticated', 'public.invitation_sends', 'select, insert, update, delete')
    and not has_table_privilege('anon', 'public.invitation_sends', 'select, insert, update, delete'),
  'only invitation_create reads and writes the record');

-- F8 · The functions closed to anon stay open to members -------------------------------------------------------------
select ok(has_function_privilege('authenticated', member_function.signature, 'execute'),
  'a member still executes ' || member_function.signature)
from unnest(array[
  'public.clinic_create(text, text, char(2), text, text)',
  'public.currency_for_country(char(2))',
  'public.days_to_expiry(date, text)',
  'public.evaluate_product_status(public.tracking_mode, numeric, numeric, numeric, numeric, integer, integer)',
  'public.membership_state()',
  'public.product_status_of(uuid)'
]) as member_function (signature);

select * from finish();
rollback;
