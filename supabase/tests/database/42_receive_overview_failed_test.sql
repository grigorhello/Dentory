-- MS-129 fix · receive_overview lists the invoices whose reading failed in Continue reviewing, each with the time it
-- failed (by invoice_reading_fail, by the each-minute timeout, or the upload's time when none was kept), among those
-- being read or ready to review, newest upload first; a failed invoice set aside afterwards (Try again and Receive
-- manually on the failure screen) is listed no more. Staff and other clinics are refused, and a read-only clinic's admin
-- still reads it.
begin;
select plan(12);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000100001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000100002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000100003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test'),
  ('00000000-0000-4000-8000-000000100004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'olivia@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, trial_ends_at) values
  ('00000000-0000-4000-8000-000000100011', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days'),
  ('00000000-0000-4000-8000-000000100012', 'Other Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days'),
  ('00000000-0000-4000-8000-000000100013', 'Lapsed Dental', 'CA', 'CAD', 'America/Toronto', now() - interval '1 day');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000100011', '00000000-0000-4000-8000-000000100001', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000100011', '00000000-0000-4000-8000-000000100002', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000100012', '00000000-0000-4000-8000-000000100003', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000100013', '00000000-0000-4000-8000-000000100004', 'olivia@dentory.test', 'Olivia Grant', 'admin', 'active');

-- Smile Dental: a Patterson invoice ready to review (2 hours ago); one being read (20 seconds ago); one whose reading
-- failed 9 minutes ago, a minute after its upload; one failed without a time kept (30 minutes ago); one the reader is
-- about to fail (1 minute ago) and one never started that the each-minute check fails (3 minutes ago); one received
-- and one set aside while it was read. Other Dental and the read-only Lapsed Dental each have a failed one.
insert into public.invoices (id, clinic_id, storage_path, source, status, supplier, created_by, created_at, read_started_at, read_at, failure_reason) values
  ('00000000-0000-4000-8000-000000100021', '00000000-0000-4000-8000-000000100011', 'a', 'camera', 'ready', 'Patterson', '00000000-0000-4000-8000-000000100001', now() - interval '2 hours', now() - interval '2 hours', now() - interval '2 hours', null),
  ('00000000-0000-4000-8000-000000100022', '00000000-0000-4000-8000-000000100011', 'b', 'file', 'reading', null, '00000000-0000-4000-8000-000000100001', now() - interval '20 seconds', now() - interval '15 seconds', null, null),
  ('00000000-0000-4000-8000-000000100023', '00000000-0000-4000-8000-000000100011', 'c', 'camera', 'failed', null, '00000000-0000-4000-8000-000000100001', now() - interval '10 minutes', now() - interval '10 minutes', now() - interval '9 minutes', 'unreadable'),
  ('00000000-0000-4000-8000-000000100024', '00000000-0000-4000-8000-000000100011', 'd', 'camera', 'failed', null, '00000000-0000-4000-8000-000000100001', now() - interval '30 minutes', null, null, null),
  ('00000000-0000-4000-8000-000000100025', '00000000-0000-4000-8000-000000100011', 'e', 'camera', 'reading', null, '00000000-0000-4000-8000-000000100001', now() - interval '1 minute', now() - interval '50 seconds', null, null),
  ('00000000-0000-4000-8000-000000100026', '00000000-0000-4000-8000-000000100011', 'f', 'file', 'reading', null, '00000000-0000-4000-8000-000000100001', now() - interval '3 minutes', null, null, null),
  ('00000000-0000-4000-8000-000000100027', '00000000-0000-4000-8000-000000100011', 'g', 'camera', 'confirmed', 'Henry Schein', '00000000-0000-4000-8000-000000100001', now() - interval '1 day', now() - interval '1 day', now() - interval '1 day', null),
  ('00000000-0000-4000-8000-000000100028', '00000000-0000-4000-8000-000000100011', 'h', 'camera', 'discarded', null, '00000000-0000-4000-8000-000000100001', now() - interval '1 day', now() - interval '1 day', null, null),
  ('00000000-0000-4000-8000-000000100029', '00000000-0000-4000-8000-000000100012', 'i', 'camera', 'failed', null, '00000000-0000-4000-8000-000000100003', now() - interval '5 minutes', now() - interval '5 minutes', now() - interval '4 minutes', 'timeout'),
  ('00000000-0000-4000-8000-000000100030', '00000000-0000-4000-8000-000000100013', 'j', 'camera', 'failed', null, '00000000-0000-4000-8000-000000100004', now() - interval '5 minutes', now() - interval '5 minutes', now() - interval '4 minutes', 'error');
update public.invoices set confirmed_at = now(), confirmed_by = created_by where id = '00000000-0000-4000-8000-000000100027';

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

-- The ids Continue reviewing lists for a clinic, in its order.
create function pg_temp.listed(p_clinic uuid) returns text[] language sql as $$
  select coalesce(array_agg(i ->> 'id' order by n), '{}')
  from jsonb_array_elements(public.receive_overview(p_clinic) -> 'invoices') with ordinality x(i, n)
$$;

select ok(not has_function_privilege('anon', 'public.receive_overview(uuid)', 'execute'), 'anon cannot read it');
select ok(has_function_privilege('authenticated', 'public.receive_overview(uuid)', 'execute'), 'members can call it');

select pg_temp.act_as('00000000-0000-4000-8000-000000100002');
select throws_ok($$ select public.receive_overview('00000000-0000-4000-8000-000000100011') $$,
  '42501', 'Only an admin can receive deliveries', 'Staff are refused');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000100003');
select throws_ok($$ select public.receive_overview('00000000-0000-4000-8000-000000100011') $$,
  '42501', 'Only an admin can receive deliveries', 'an admin of another clinic is refused');
select is(pg_temp.listed('00000000-0000-4000-8000-000000100012'), array['00000000-0000-4000-8000-000000100029'],
  'and sees only their own clinic''s failed invoice');
reset role;

-- The reader gives up on one invoice, and the each-minute check fails the one that never started.
select lives_ok($$ select public.invoice_reading_fail('00000000-0000-4000-8000-000000100025', 'error') $$,
  'the reader fails an invoice');
select engine.invoice_reading_timeout();

select pg_temp.act_as('00000000-0000-4000-8000-000000100001');
select is(pg_temp.listed('00000000-0000-4000-8000-000000100011'),
  array['00000000-0000-4000-8000-000000100022', '00000000-0000-4000-8000-000000100025',
        '00000000-0000-4000-8000-000000100026', '00000000-0000-4000-8000-000000100023',
        '00000000-0000-4000-8000-000000100024', '00000000-0000-4000-8000-000000100021'],
  'Continue reviewing lists the invoices being read, ready to review and whose reading failed, newest upload first; received and set-aside ones stay out');
select results_eq(
  $$ select i ->> 'status', i ->> 'supplier', (i ->> 'created_at')::timestamptz, (i ->> 'failed_at')::timestamptz
     from jsonb_array_elements(public.receive_overview('00000000-0000-4000-8000-000000100011') -> 'invoices') i $$,
  $$ values ('reading', null, now() - interval '20 seconds', null::timestamptz),
            ('failed', null, now() - interval '1 minute', now()),
            ('failed', null, now() - interval '3 minutes', now()),
            ('failed', null, now() - interval '10 minutes', now() - interval '9 minutes'),
            ('failed', null, now() - interval '30 minutes', now() - interval '30 minutes'),
            ('ready', 'Patterson', now() - interval '2 hours', null) $$,
  'a failed invoice carries the time its reading failed (the upload''s when none was kept); the others carry none');

-- Try again or Receive manually on the failure screen sets the invoice aside.
select is(public.invoice_discard('00000000-0000-4000-8000-000000100023') ->> 'status', 'discarded',
  'the admin sets a failed invoice aside');
select ok(not ('00000000-0000-4000-8000-000000100023' = any (pg_temp.listed('00000000-0000-4000-8000-000000100011'))),
  'and Continue reviewing no longer lists it');
reset role;

-- A read-only clinic's admin still reads it (the app keeps them off the screen, MS-142).
select pg_temp.act_as('00000000-0000-4000-8000-000000100004');
select ok(not public.clinic_can_write('00000000-0000-4000-8000-000000100013'), 'Lapsed Dental is read-only');
select is(pg_temp.listed('00000000-0000-4000-8000-000000100013'), array['00000000-0000-4000-8000-000000100030'],
  'and its admin still sees its failed invoice');
reset role;

select * from finish();
rollback;
