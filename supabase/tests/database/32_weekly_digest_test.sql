-- MS-145 · Weekly email digest: the Monday 7 am queue at each clinic's time, the switch and read-only clinics, what the
-- digest says (Home's counts, the five batches expiring soonest, last week's procedures, the admins), the claim and its
-- retry, the preview, and who may call them. Counts are scoped to this file's clinics: CI runs it on the demo seed too.
begin;
select plan(38);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000021401', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000021402', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000021403', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'daniel@dentory.test');
insert into public.profiles (user_id, full_name) values ('00000000-0000-4000-8000-000000021401', 'Sarah Mitchell');

-- A: the clinic whose digest is read (Toronto, the switch left at its default). B: Kolkata. C: read-only. D: a time
-- zone Postgres does not know. E: the switch off. F: switched off after its digest was queued.
insert into public.clinics (id, name, country, currency, time_zone) values
  ('00000000-0000-4000-8000-000000021411', 'Clinique Laval', 'CA', 'CAD', 'America/Toronto');
insert into public.clinics (id, name, country, currency, time_zone, email_digest, trial_ends_at) values
  ('00000000-0000-4000-8000-000000021412', 'Kolkata Dental', 'IN', 'INR', 'Asia/Kolkata', true, now() + interval '30 days'),
  ('00000000-0000-4000-8000-000000021413', 'Lapsed Dental', 'GB', 'GBP', 'UTC', true, now() - interval '1 day'),
  ('00000000-0000-4000-8000-000000021414', 'Mars Dental', 'CA', 'CAD', 'Mars/Olympus', true, now() + interval '30 days'),
  ('00000000-0000-4000-8000-000000021415', 'Quiet Dental', 'CA', 'CAD', 'America/Toronto', false, now() + interval '30 days'),
  ('00000000-0000-4000-8000-000000021416', 'Switch Dental', 'CA', 'CAD', 'America/Toronto', true, now() + interval '30 days');

insert into public.memberships (clinic_id, user_id, email, full_name, role, status, invited_at) values
  ('00000000-0000-4000-8000-000000021411', '00000000-0000-4000-8000-000000021401', 'sarah@dentory.test', '', 'admin',
   'active', '2026-09-01 12:00:00+00'),
  ('00000000-0000-4000-8000-000000021411', '00000000-0000-4000-8000-000000021402', 'michael@dentory.test',
   'Michael Reyes', 'staff', 'active', '2026-09-02 12:00:00+00'),
  ('00000000-0000-4000-8000-000000021411', '00000000-0000-4000-8000-000000021403', 'daniel.kim@clinic.test',
   'Dr. Daniel Kim', 'admin', 'active', '2026-09-03 12:00:00+00'),
  ('00000000-0000-4000-8000-000000021411', null, 'ivy@dentory.test', 'Ivy Chen', 'admin', 'invited',
   '2026-09-04 12:00:00+00');

-- Clinique Laval's stock, its months counted from today at the clinic: six batches expire within 90 days (two already
-- expired), one in four months does not, and Gloves has stock without an expiry.
create temp table months on commit drop as
  select date_trunc('month', now() at time zone 'America/Toronto')::date as m0;
insert into public.products (id, clinic_id, name, unit, archived_at) values
  ('00000000-0000-4000-8000-000000021421', '00000000-0000-4000-8000-000000021411', 'Alginate', 'bags', null),
  ('00000000-0000-4000-8000-000000021422', '00000000-0000-4000-8000-000000021411', 'Bonding agent', 'bottles', null),
  ('00000000-0000-4000-8000-000000021423', '00000000-0000-4000-8000-000000021411', 'Composite A2', 'syringes', null),
  ('00000000-0000-4000-8000-000000021424', '00000000-0000-4000-8000-000000021411', 'Septocaine 4%', 'cartridges', null),
  ('00000000-0000-4000-8000-000000021425', '00000000-0000-4000-8000-000000021411', 'Gloves', 'boxes', null),
  ('00000000-0000-4000-8000-000000021426', '00000000-0000-4000-8000-000000021411', 'Wipes', 'canisters', null),
  ('00000000-0000-4000-8000-000000021427', '00000000-0000-4000-8000-000000021411', 'Impression trays', 'boxes', null),
  ('00000000-0000-4000-8000-000000021428', '00000000-0000-4000-8000-000000021411', 'Old cement', 'tubes',
   '2026-09-30 15:00:00+00');
insert into public.batches (clinic_id, product_id, expiry_month, lot, qty)
select '00000000-0000-4000-8000-000000021411', b.product_id::uuid, (m.m0 + b.shift)::date, b.lot, b.qty
from months m, (values
  ('00000000-0000-4000-8000-000000021421', interval '-2 months', null, 2),
  ('00000000-0000-4000-8000-000000021422', interval '-1 month', 'BA7', 1),
  ('00000000-0000-4000-8000-000000021423', interval '0 months', 'C1', 4),
  ('00000000-0000-4000-8000-000000021423', interval '0 months', 'C0', 0),
  ('00000000-0000-4000-8000-000000021424', interval '0 months', 'S1', 30),
  ('00000000-0000-4000-8000-000000021425', interval '1 month', 'G1', 3),
  ('00000000-0000-4000-8000-000000021426', interval '1 month', null, 1),
  ('00000000-0000-4000-8000-000000021427', interval '4 months', null, 5),
  ('00000000-0000-4000-8000-000000021428', interval '0 months', null, 5)
) as b (product_id, shift, lot, qty);
insert into public.batches (clinic_id, product_id, expiry_month, qty) values
  ('00000000-0000-4000-8000-000000021411', '00000000-0000-4000-8000-000000021425', null, 2);
insert into public.to_buy_items (clinic_id, product_id, qty, status, ordered_at) values
  ('00000000-0000-4000-8000-000000021411', '00000000-0000-4000-8000-000000021421', 10, 'to_buy', null),
  ('00000000-0000-4000-8000-000000021411', '00000000-0000-4000-8000-000000021422', 2, 'to_buy', null),
  ('00000000-0000-4000-8000-000000021411', '00000000-0000-4000-8000-000000021424', 50, 'ordered', now());
-- Last week at the clinic is Monday October 12 to Sunday October 18: two procedures count, not the cancelled one, nor
-- those either side of the week.
insert into public.procedure_events (clinic_id, name, started_by, started_at, cancelled_at, cancelled_by, cancel_note)
values
  ('00000000-0000-4000-8000-000000021411', 'Filling', '00000000-0000-4000-8000-000000021401', '2026-10-13 14:00:00+00',
   null, null, null),
  ('00000000-0000-4000-8000-000000021411', 'Filling', '00000000-0000-4000-8000-000000021401', '2026-10-19 03:30:00+00',
   null, null, null),
  ('00000000-0000-4000-8000-000000021411', 'Filling', '00000000-0000-4000-8000-000000021401', '2026-10-19 04:30:00+00',
   null, null, null),
  ('00000000-0000-4000-8000-000000021411', 'Filling', '00000000-0000-4000-8000-000000021401', '2026-10-12 03:30:00+00',
   null, null, null),
  ('00000000-0000-4000-8000-000000021411', 'Filling', '00000000-0000-4000-8000-000000021401', '2026-10-14 15:00:00+00',
   '2026-10-14 16:00:00+00', '00000000-0000-4000-8000-000000021401', 'Wrong patient chair');

create temp view mine as
  select d.*, c.name as clinic
  from public.digest_sends d join public.clinics c on c.id = d.clinic_id
  where d.clinic_id::text like '00000000-0000-4000-8000-0000000214%';

-- The switch and who may call what.
select ok((select email_digest from public.clinics where id = '00000000-0000-4000-8000-000000021411'),
  'a new clinic starts with the digest on');
select ok(not has_function_privilege('authenticated', 'public.digest_claim(integer)', 'execute'),
  'members cannot claim digests');
select ok(not has_function_privilege('authenticated', 'public.digest_finish(uuid[], integer[])', 'execute'),
  'nor mark them sent');
select ok(not has_function_privilege('authenticated', 'public.digest_preview(uuid)', 'execute'),
  'nor read a clinic''s digest');
select ok(has_function_privilege('service_role', 'public.digest_claim(integer)', 'execute'),
  'the function claims them');
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-4000-8000-000000021401', 'role', 'authenticated')::text, true);
set local role authenticated;
select throws_ok($$select count(*) from public.digest_sends$$, '42501', null, 'members cannot read the sends');
reset role;

-- The queue: Monday 7 am at each clinic.
select lives_ok($$select engine.digest_queue('2026-10-19 11:00:00+00')$$,
  'Monday 7 am in Toronto queues, a time zone Postgres does not know included');
select results_eq($$select clinic, week from mine order by clinic$$,
  $$values ('Clinique Laval', '2026-10-19'::date), ('Lapsed Dental', '2026-10-19'::date),
           ('Switch Dental', '2026-10-19'::date)$$,
  'Toronto''s clinics with the switch on, and UTC''s at 11 am; not Kolkata at 4:30 pm, nor the switch off or Mars');
select engine.digest_queue('2026-10-19 11:30:00+00');
select is((select count(*)::integer from mine where clinic = 'Clinique Laval'), 1, 'once a week per clinic');
select engine.digest_queue('2026-10-19 01:30:00+00');
select is((select week from mine where clinic = 'Kolkata Dental'), '2026-10-19'::date,
  'Kolkata''s Monday 7 am is Sunday night in Toronto');

-- The claim.
update public.clinics set email_digest = false where id = '00000000-0000-4000-8000-000000021416';
create temp table claimed on commit drop as
  select d from jsonb_array_elements(public.digest_claim(50)) d;
create temp view laval as select d from claimed where d->>'clinic_name' = 'Clinique Laval';
select is((select count(*)::integer from claimed where d->>'clinic_name' in ('Clinique Laval', 'Kolkata Dental')), 2,
  'the claim takes Clinique Laval and Kolkata Dental');
select is((select skipped from mine where clinic = 'Switch Dental'), 'off',
  'a digest switched off before the send is dropped');
select is((select skipped from mine where clinic = 'Lapsed Dental'), 'read_only', 'a read-only clinic gets none');
select is((select count(*)::integer from claimed where d->>'clinic_name' in ('Switch Dental', 'Lapsed Dental')), 0,
  'and neither is claimed');
select is((select d->>'id' from laval), (select id::text from mine where clinic = 'Clinique Laval'),
  'each digest carries its row''s id');
select is(
  (select jsonb_build_array(d->'week', d->'window', d->'to_buy', d->'expiring', d->'missing_expiry', d->'procedures')
   from laval),
  '["2026-10-19", 90, 2, 6, 1, 2]'::jsonb,
  'Home''s counts, the window and last week''s procedures (not the cancelled one, nor the days either side)'
);
select is(
  (select jsonb_agg(s->>'name' order by n) from laval, jsonb_array_elements(d->'soonest') with ordinality as x (s, n)),
  '["Alginate", "Bonding agent", "Composite A2", "Septocaine 4%", "Gloves"]'::jsonb,
  'the five batches expiring soonest, the expired first, as Expiring soon orders them'
);
select ok((select (d->'soonest'->0->>'days')::integer < 0 and (d->'soonest'->2->>'days')::integer >= 0 from laval),
  'with their days, negative once expired');
select is((select (d->'soonest'->3) - 'days' from laval),
  jsonb_build_object('name', 'Septocaine 4%', 'qty', 30.00, 'unit', 'cartridges', 'lot', 'S1',
    'expiry_month', (select m0 from months)),
  'with the quantity, unit, lot and month the email describes');
select is((select d->'recipients' from laval),
  '[{"email": "sarah@dentory.test", "name": "Sarah Mitchell"}, {"email": "daniel@dentory.test", "name": "Dr. Daniel Kim"}]'::jsonb,
  'to the active admins at their sign-in address, not staff nor an invitation');
select ok((select claimed_at is not null and sent_at is null from mine where clinic = 'Clinique Laval'),
  'a claimed digest waits for its result');
select is((select count(*)::integer from jsonb_array_elements(public.digest_claim(50)) d
           where d->>'clinic_name' in ('Clinique Laval', 'Kolkata Dental')), 0,
  'a claim younger than 10 minutes is not taken again');

-- The result.
select public.digest_finish(array[(select id from mine where clinic = 'Clinique Laval')], array[2]);
select ok((select sent_at is not null and recipients = 2 from mine where clinic = 'Clinique Laval'),
  'a sent digest records how many admins it reached');
update public.digest_sends set claimed_at = now() - interval '11 minutes'
  where id = (select id from mine where clinic = 'Kolkata Dental');
select is((select count(*)::integer from jsonb_array_elements(public.digest_claim(50)) d
           where d->>'clinic_name' = 'Kolkata Dental'), 1,
  'one that did not go out is claimed again 10 minutes later');
select is((select count(*)::integer from jsonb_array_elements(public.digest_claim(50)) d
           where d->>'clinic_name' = 'Clinique Laval'), 0, 'a sent one never is');
update public.digest_sends set created_at = now() - interval '7 hours', claimed_at = null
  where id = (select id from mine where clinic = 'Kolkata Dental');
select is((select count(*)::integer from jsonb_array_elements(public.digest_claim(50)) d
           where d->>'clinic_name' = 'Kolkata Dental'), 0, 'nor one queued more than 6 hours ago');
select is((select skipped from mine where clinic = 'Kolkata Dental'), 'late', 'which is dropped as late');

-- The preview, to try the email on a hosted project.
select is(
  (select jsonb_build_array(p->'week', p->'to_buy', p->'expiring', p ? 'id')
   from public.digest_preview('00000000-0000-4000-8000-000000021411') p),
  jsonb_build_array(date_trunc('week', now() at time zone 'America/Toronto')::date, 2, 6, false),
  'the preview reads this week''s digest without a row'
);
select is(public.digest_preview('00000000-0000-4000-8000-0000000214ff'), null, 'and nothing for an unknown clinic');

-- The hours and days around Monday 7 am.
select engine.digest_queue('2026-10-26 10:00:00+00');
select is((select count(*)::integer from mine where week = '2026-10-26' and clinic = 'Clinique Laval'), 0,
  'not before 7 am');
select engine.digest_queue('2026-10-26 16:00:00+00');
select is((select count(*)::integer from mine where week = '2026-10-26' and clinic = 'Clinique Laval'), 0,
  'nor from noon');
select engine.digest_queue('2026-10-26 15:59:00+00');
select is((select count(*)::integer from mine where week = '2026-10-26' and clinic = 'Clinique Laval'), 1,
  'a missed hour catches up until noon');
select engine.digest_queue('2026-10-25 11:00:00+00');
select is((select count(*)::integer from mine where week = '2026-10-25'), 0, 'nothing on a Sunday, anywhere');
select engine.digest_queue('2026-11-02 11:00:00+00');
select is((select count(*)::integer from mine where week = '2026-11-02' and clinic = 'Clinique Laval'), 0,
  'after the clocks go back, 11:00 UTC is 6 am in Toronto');
select engine.digest_queue('2026-11-02 12:00:00+00');
select is((select count(*)::integer from mine where week = '2026-11-02' and clinic = 'Clinique Laval'), 1,
  'and 12:00 UTC is 7 am');
select is((select count(*)::integer from mine where clinic = 'Mars Dental'), 0,
  'a clinic whose time zone Postgres does not know is never queued');

-- The hourly job.
select is((select count(*)::integer from cron.job where jobname = 'weekly-digest' and schedule = '0 * * * *'), 1,
  'the job runs each hour');
select lives_ok($$select engine.digest_dispatch()$$, 'a dispatch without Vault secrets sends nothing');

select * from finish();
rollback;
