-- MS-144 · Push notifications: which alerts queue a push, one per product per day and once per expiring batch, quiet
-- hours, what push_claim answers and to whose devices, what it skips, push_finish, the device token RPCs, the shared
-- APNs provider token, the cron job.
begin;
select plan(42);

-- The demo seed's alerts queued pushes of their own when CI loads it; this test counts its own rows only.
update public.push_outbox set skipped = 'stale' where sent_at is null and skipped is null;

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000014401', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000014402', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000014403', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test'),
  ('00000000-0000-4000-8000-000000014404', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'removed@dentory.test');
-- Pushes wait for the clinic's waking hours, 7 am to 9 pm: the clinics below keep a clock on which it is midday now,
-- and Night Dental one on which it is 11 pm, whatever the hour the test runs.
create function pg_temp.zone_at(p_hour integer) returns text language sql as $$
  select case when o = 0 then 'Etc/GMT' when o > 0 then 'Etc/GMT-' || o else 'Etc/GMT+' || -o end
  from (select ((p_hour - extract(hour from now() at time zone 'UTC')::integer + 36) % 24) - 12 as o) x;
$$;
insert into public.clinics (id, name, country, currency, time_zone) values
  ('00000000-0000-4000-8000-000000014411', 'Smile Dental', 'CA', 'CAD', pg_temp.zone_at(12)),
  ('00000000-0000-4000-8000-000000014412', 'Other Dental', 'CA', 'CAD', pg_temp.zone_at(12)),
  ('00000000-0000-4000-8000-000000014413', 'Night Dental', 'CA', 'CAD', pg_temp.zone_at(23));
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000014411', '00000000-0000-4000-8000-000000014401', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000014411', '00000000-0000-4000-8000-000000014402', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000014411', '00000000-0000-4000-8000-000000014404', 'removed@dentory.test', 'Removed Member', 'staff', 'revoked'),
  ('00000000-0000-4000-8000-000000014412', '00000000-0000-4000-8000-000000014403', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
insert into public.memberships (clinic_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000014411', 'invited@dentory.test', 'Invited Member', 'staff', 'invited');
insert into public.push_tokens (user_id, token) values
  ('00000000-0000-4000-8000-000000014401', repeat('a', 64)),
  ('00000000-0000-4000-8000-000000014402', repeat('b', 64)),
  ('00000000-0000-4000-8000-000000014403', repeat('c', 64)),
  ('00000000-0000-4000-8000-000000014404', repeat('d', 64));
insert into public.products (id, clinic_id, name, unit, tracking) values
  ('00000000-0000-4000-8000-000000014421', '00000000-0000-4000-8000-000000014411', 'Rubber dam latex-free', 'sheets', 'countable'),
  ('00000000-0000-4000-8000-000000014422', '00000000-0000-4000-8000-000000014411', 'Bonding agent', 'bottles', 'multi_use'),
  ('00000000-0000-4000-8000-000000014423', '00000000-0000-4000-8000-000000014411', 'Gloves', 'boxes', 'countable'),
  ('00000000-0000-4000-8000-000000014424', '00000000-0000-4000-8000-000000014411', 'Old cement', 'tubes', 'countable'),
  ('00000000-0000-4000-8000-000000014425', '00000000-0000-4000-8000-000000014412', 'Other gloves', 'boxes', 'countable'),
  ('00000000-0000-4000-8000-000000014426', '00000000-0000-4000-8000-000000014413', 'Night gloves', 'boxes', 'countable');
-- Bonding agent's batch ends next month, so it expires in more than a day.
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000014431', '00000000-0000-4000-8000-000000014411', '00000000-0000-4000-8000-000000014422',
   (date_trunc('month', (now() at time zone pg_temp.zone_at(12))) + interval '1 month')::date, 'BA7', 1);
insert into public.invoices (id, clinic_id, source, storage_path, status, supplier, created_by) values
  ('00000000-0000-4000-8000-000000014441', '00000000-0000-4000-8000-000000014411', 'file', 'invoices/patterson.pdf', 'ready', 'Patterson Dental', '00000000-0000-4000-8000-000000014401');

create function pg_temp.open_alert(
  p_id text, p_kind public.alert_kind, p_product text, p_batch text default null, p_threshold int default null,
  p_invoice text default null, p_clinic text default '00000000-0000-4000-8000-000000014411'
) returns void language sql as $$
  insert into public.alerts (id, clinic_id, kind, product_id, batch_id, threshold_days, invoice_id)
  values (p_id::uuid, p_clinic::uuid, p_kind, p_product::uuid, p_batch::uuid, p_threshold, p_invoice::uuid);
$$;
create function pg_temp.queued(p_alert text) returns integer language sql as $$
  select count(*)::integer from public.push_outbox where alert_id = p_alert::uuid;
$$;

-- Which alerts queue a push.
select pg_temp.open_alert('00000000-0000-4000-8000-000000014451', 'out_of_stock', '00000000-0000-4000-8000-000000014421');
select is(pg_temp.queued('00000000-0000-4000-8000-000000014451'), 1, 'out of stock queues a push');
select ok((select abs(extract(epoch from (not_before - now()))) < 1 from public.push_outbox
  where alert_id = '00000000-0000-4000-8000-000000014451'), 'the first push of a product is due at once');
select pg_temp.open_alert('00000000-0000-4000-8000-000000014452', 'low', '00000000-0000-4000-8000-000000014423');
select pg_temp.open_alert('00000000-0000-4000-8000-000000014453', 'missing_expiry', '00000000-0000-4000-8000-000000014423');
select is(pg_temp.queued('00000000-0000-4000-8000-000000014452') + pg_temp.queued('00000000-0000-4000-8000-000000014453'), 0,
  'low and missing expiry stay in the app');
select pg_temp.open_alert('00000000-0000-4000-8000-000000014454', 'expiring', '00000000-0000-4000-8000-000000014422', '00000000-0000-4000-8000-000000014431', 60);
select is(pg_temp.queued('00000000-0000-4000-8000-000000014454'), 0, 'expiring within 60 days stays in the app');
select pg_temp.open_alert('00000000-0000-4000-8000-000000014455', 'expiring', '00000000-0000-4000-8000-000000014422', '00000000-0000-4000-8000-000000014431', 30);
select is(pg_temp.queued('00000000-0000-4000-8000-000000014455'), 1, 'expiring within 30 days queues a push');
select pg_temp.open_alert('00000000-0000-4000-8000-000000014456', 'invoice_ready', null, null, null, '00000000-0000-4000-8000-000000014441');
select is(pg_temp.queued('00000000-0000-4000-8000-000000014456'), 1, 'a delivery ready to review queues a push');

-- One push per product per day; an expiring batch pushes once.
update public.push_outbox set sent_at = now() where alert_id = '00000000-0000-4000-8000-000000014451';
update public.alerts set resolved_at = now() where id = '00000000-0000-4000-8000-000000014451';
select pg_temp.open_alert('00000000-0000-4000-8000-000000014457', 'out_of_stock', '00000000-0000-4000-8000-000000014421');
select ok((select abs(extract(epoch from (not_before - (now() + interval '1 day')))) < 1 from public.push_outbox
  where alert_id = '00000000-0000-4000-8000-000000014457'), 'running out again the same day waits a day');
-- Restocked before that push went out, then out again: the push that never went out holds nothing back.
update public.alerts set resolved_at = now() where id = '00000000-0000-4000-8000-000000014457';
select pg_temp.open_alert('00000000-0000-4000-8000-00000001445c', 'out_of_stock', '00000000-0000-4000-8000-000000014421');
select ok((select abs(extract(epoch from (not_before - (now() + interval '1 day')))) < 1 from public.push_outbox
  where alert_id = '00000000-0000-4000-8000-00000001445c'), 'a push that never went out does not hold the next one back');
update public.alerts set resolved_at = now() where id = '00000000-0000-4000-8000-000000014455';
select pg_temp.open_alert('00000000-0000-4000-8000-000000014458', 'expiring', '00000000-0000-4000-8000-000000014422', '00000000-0000-4000-8000-000000014431', 30);
select is(pg_temp.queued('00000000-0000-4000-8000-000000014458'), 0, 'a batch that expires again is not pushed twice');
delete from public.alerts where id = '00000000-0000-4000-8000-000000014458';
update public.alerts set resolved_at = null where id = '00000000-0000-4000-8000-000000014455';

-- Quiet hours: a push due at night waits for 7 am in the clinic's time zone.
select is(engine.push_waking_time('2026-10-21 02:30:00+00', 'America/Toronto'), '2026-10-21 11:00:00+00'::timestamptz,
  'a push due at 10:30 pm waits for 7 am the next morning');
select is(engine.push_waking_time('2026-10-21 09:15:00+00', 'America/Toronto'), '2026-10-21 11:00:00+00'::timestamptz,
  'one due at 5:15 am waits for 7 am the same morning');
select is(engine.push_waking_time('2026-10-21 15:00:00+00', 'America/Toronto'), '2026-10-21 15:00:00+00'::timestamptz,
  'one due during the day goes out then');
select pg_temp.open_alert('00000000-0000-4000-8000-00000001445d', 'out_of_stock', '00000000-0000-4000-8000-000000014426', null, null, null,
  '00000000-0000-4000-8000-000000014413');
select is((select not_before from public.push_outbox where alert_id = '00000000-0000-4000-8000-00000001445d'),
  ((now() at time zone pg_temp.zone_at(23))::date + 1 + time '07:00') at time zone pg_temp.zone_at(23),
  'running out at 11 pm in the clinic pushes at 7 am');

-- Old cement ran out two days ago and its push never went out; an archived product's push is dropped.
select pg_temp.open_alert('00000000-0000-4000-8000-000000014459', 'out_of_stock', '00000000-0000-4000-8000-000000014424');
update public.push_outbox set not_before = now() - interval '2 days' where alert_id = '00000000-0000-4000-8000-000000014459';
select pg_temp.open_alert('00000000-0000-4000-8000-00000001445a', 'out_of_stock', '00000000-0000-4000-8000-000000014423');
update public.products set archived_at = now() where id = '00000000-0000-4000-8000-000000014423';
select pg_temp.open_alert('00000000-0000-4000-8000-00000001445b', 'out_of_stock', '00000000-0000-4000-8000-000000014425', null, null, null,
  '00000000-0000-4000-8000-000000014412');

-- Only the service role sends.
select ok(not has_function_privilege('authenticated', 'public.push_claim(integer)', 'execute'), 'members cannot claim pushes');
select ok(not has_function_privilege('authenticated', 'public.push_finish(uuid[], text[])', 'execute'), 'members cannot mark pushes sent');
select ok(not has_table_privilege('authenticated', 'public.push_outbox', 'select'), 'members cannot read the outbox');

create temp table claimed on commit drop as select * from public.push_claim(50);
select is((select count(*)::integer from claimed), 3, 'the due pushes of both clinics, not the one waiting a day');
select is((select title from claimed where outbox_id = (select id from public.push_outbox where alert_id = '00000000-0000-4000-8000-000000014455')),
  'Smile Dental', 'the title is the clinic');
select is((select skipped from public.push_outbox where alert_id = '00000000-0000-4000-8000-000000014457'), 'resolved',
  'a push whose alert closed first is skipped');
select is((select skipped from public.push_outbox where alert_id = '00000000-0000-4000-8000-000000014459'), 'stale',
  'a push undelivered for a day is dropped');
select is((select skipped from public.push_outbox where alert_id = '00000000-0000-4000-8000-00000001445a'), 'archived',
  'an archived product is not pushed');
select results_eq(
  $$select body, link, tokens from claimed
    where outbox_id = (select id from public.push_outbox where alert_id = '00000000-0000-4000-8000-000000014455')$$,
  $$values ('Bonding agent expires in ' || public.days_to_expiry(
      (date_trunc('month', (now() at time zone pg_temp.zone_at(12))) + interval '1 month')::date, pg_temp.zone_at(12)) || ' days.',
    'dentory://product/00000000-0000-4000-8000-000000014422', array[repeat('a', 64), repeat('b', 64)])$$,
  'expiring reads as Activity does, opens the product and goes to every active member'
);
select results_eq(
  $$select body, link, tokens from claimed
    where outbox_id = (select id from public.push_outbox where alert_id = '00000000-0000-4000-8000-000000014456')$$,
  $$values ('Delivery from Patterson Dental is read and waiting for review.', 'dentory://delivery', array[repeat('a', 64)])$$,
  'a delivery ready to review goes to admins only and opens Receive delivery'
);
select results_eq(
  $$select body, tokens from claimed
    where outbox_id = (select id from public.push_outbox where alert_id = '00000000-0000-4000-8000-00000001445b')$$,
  $$values ('Other gloves is out of stock.', array[repeat('c', 64)])$$,
  'another clinic''s push goes to its own members'
);
select is((select count(*)::integer from public.push_claim(50)), 0, 'claimed pushes are not handed out twice');

-- push_finish: sent rows and dead tokens.
select public.push_finish(
  array(select outbox_id from claimed where link = 'dentory://delivery'), array[repeat('c', 64)]
);
select ok((select sent_at is not null from public.push_outbox where alert_id = '00000000-0000-4000-8000-000000014456'),
  'a sent push is recorded');
select is((select count(*)::integer from public.push_tokens where token = repeat('c', 64)), 0,
  'a token APNs no longer knows is deleted');
update public.push_outbox set claimed_at = now() - interval '11 minutes' where sent_at is null and skipped is null and claimed_at is not null;
select is((select count(*)::integer from public.push_claim(50)), 2, 'an unsent claim is retried after 10 minutes');

-- Device tokens.
select ok(not has_function_privilege('anon', 'public.push_token_register(text)', 'execute'), 'anon cannot register a device');
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
select pg_temp.act_as('00000000-0000-4000-8000-000000014401');
select public.push_token_register(repeat('e', 64));
select is((select count(*)::integer from public.push_tokens where token = repeat('e', 64)), 1, 'a member registers this device');
select throws_ok($$select public.push_token_register('not a token')$$, '22023', 'Not a device token', 'a malformed token is refused');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000014402');
select public.push_token_register(repeat('e', 64));
reset role;
select is((select user_id from public.push_tokens where token = repeat('e', 64)), '00000000-0000-4000-8000-000000014402'::uuid,
  'a device signed in by someone else becomes theirs');
select pg_temp.act_as('00000000-0000-4000-8000-000000014401');
select public.push_token_remove(repeat('e', 64));
reset role;
select is((select count(*)::integer from public.push_tokens where token = repeat('e', 64)), 1, 'a member cannot remove another''s device');
select pg_temp.act_as('00000000-0000-4000-8000-000000014402');
select public.push_token_remove(repeat('e', 64));
reset role;
select is((select count(*)::integer from public.push_tokens where token = repeat('e', 64)), 0, 'signing out removes this device');

-- The APNs provider token the function's instances share, renewed once it is 50 minutes old.
select ok(not has_function_privilege('authenticated', 'public.push_provider_token(text)', 'execute'),
  'members cannot read the provider token');
select is(public.push_provider_token_save('KEY1', 'first'), 'first', 'a newly signed token is kept');
select is(public.push_provider_token_save('KEY1', 'second'), 'first', 'one signed meanwhile gives way to the kept one');
select is(public.push_provider_token('KEY1'), 'first', 'every instance reads the kept one');
update public.push_provider_tokens set issued_at = now() - interval '51 minutes' where key_id = 'KEY1';
select ok(public.push_provider_token('KEY1') is null, 'one 50 minutes old is not handed out');
select is(public.push_provider_token_save('KEY1', 'third'), 'third', 'the next one signed replaces it');

-- The cron job, and a dispatch without the function's URL in Vault sends nothing.
select is((select count(*)::integer from cron.job where jobname = 'send-push' and schedule = '* * * * *'), 1, 'the job runs each minute');
select lives_ok($$select engine.push_dispatch()$$, 'a dispatch without Vault secrets is a no-op');

select * from finish();
rollback;
