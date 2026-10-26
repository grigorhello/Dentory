-- MS-144 fix (Refs #115) · An expiring batch pushes once per expiry month: Edit batch (MS-119) moving a pushed batch
-- to a later month lets that month push once it comes within 30 days, the same month never queues twice, idempotent
-- replays move nothing, and Out of stock and the delivery ready to review queue as before.
begin;
select plan(21);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000115001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000115002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test');
-- Smile Dental warns at 30, 60 and 90 days; only the 30-day alert pushes (MS-144).
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-000000115011', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', '{30,60,90}');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000115011', '00000000-0000-4000-8000-000000115001', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000115011', '00000000-0000-4000-8000-000000115002', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active');

-- A month counted from this month in the clinic. A batch expires at the end of its month, so 0 is within 30 days,
-- -1 and -2 have expired (within 30 days too), and 8 is past every warning.
create function pg_temp.month(p_offset integer) returns date language sql as $$
  select (date_trunc('month', now() at time zone 'America/Toronto') + make_interval(months => p_offset))::date;
$$;

-- Septocaine's lot A112 is dated eight months out and Bonding agent's lot BA7 this month; Gloves have none left;
-- a delivery from Patterson Dental is read and waiting for review.
insert into public.products (id, clinic_id, name, unit, tracking) values
  ('00000000-0000-4000-8000-000000115021', '00000000-0000-4000-8000-000000115011', 'Septocaine 4% 1:100,000', 'cartridges', 'countable'),
  ('00000000-0000-4000-8000-000000115022', '00000000-0000-4000-8000-000000115011', 'Gloves', 'boxes', 'countable'),
  ('00000000-0000-4000-8000-000000115023', '00000000-0000-4000-8000-000000115011', 'Bonding agent', 'bottles', 'countable');
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000115031', '00000000-0000-4000-8000-000000115011', '00000000-0000-4000-8000-000000115021', pg_temp.month(8), 'A112', 20),
  ('00000000-0000-4000-8000-000000115033', '00000000-0000-4000-8000-000000115011', '00000000-0000-4000-8000-000000115023', pg_temp.month(0), 'BA7', 2);
insert into public.invoices (id, clinic_id, source, storage_path, status, supplier, created_by) values
  ('00000000-0000-4000-8000-000000115041', '00000000-0000-4000-8000-000000115011', 'file', 'invoices/patterson.pdf', 'ready', 'Patterson Dental', '00000000-0000-4000-8000-000000115001');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
-- The expiring pushes queued for a batch, the months they were queued for, and the batch's open expiring alerts.
create function pg_temp.pushes(p_batch uuid) returns integer language sql as $$
  select count(*)::integer from public.push_outbox where batch_id = p_batch and kind = 'expiring';
$$;
create function pg_temp.months(p_batch uuid) returns date[] language sql as $$
  select array_agg(expiry_month order by expiry_month)
  from public.push_outbox where batch_id = p_batch and kind = 'expiring';
$$;
create function pg_temp.open_alerts(p_batch uuid) returns integer language sql as $$
  select count(*)::integer from public.alerts where batch_id = p_batch and kind = 'expiring' and resolved_at is null;
$$;

-- Staff dates Septocaine's batch this month with Edit batch: its push is queued once, for that month.
select pg_temp.act_as('00000000-0000-4000-8000-000000115002');
select public.batch_upsert('00000000-0000-4000-8000-000000115021', '00000000-0000-4000-8000-000000115031',
  pg_temp.month(0), 20, 'A112', '00000000-0000-4000-8000-000000115061');
reset role;
select is(pg_temp.pushes('00000000-0000-4000-8000-000000115031'), 1, 'a batch dated within 30 days queues its push');
select is(pg_temp.months('00000000-0000-4000-8000-000000115031'), array[pg_temp.month(0)], 'for the batch''s expiry month');
select public.refresh_product('00000000-0000-4000-8000-000000115021');
select is(pg_temp.pushes('00000000-0000-4000-8000-000000115031'), 1, 'the nightly refresh does not queue it again');

-- The month was wrong: Edit batch corrects it to eight months out. The alerts close and nothing is queued.
select pg_temp.act_as('00000000-0000-4000-8000-000000115002');
select public.batch_upsert('00000000-0000-4000-8000-000000115021', '00000000-0000-4000-8000-000000115031',
  pg_temp.month(8), 20, 'A112', '00000000-0000-4000-8000-000000115062');
reset role;
select is(pg_temp.open_alerts('00000000-0000-4000-8000-000000115031'), 0, 'a later month closes the batch''s alerts');
select is(pg_temp.pushes('00000000-0000-4000-8000-000000115031'), 1, 'and queues nothing');

-- Months later the corrected month comes within 30 days and the nightly refresh opens its 30-day alert (opened here
-- by hand, since the clock cannot move inside a test): the batch pushes again, for its new month.
insert into public.alerts (id, clinic_id, kind, product_id, batch_id, threshold_days) values
  ('00000000-0000-4000-8000-000000115051', '00000000-0000-4000-8000-000000115011', 'expiring',
   '00000000-0000-4000-8000-000000115021', '00000000-0000-4000-8000-000000115031', 30);
select is(pg_temp.pushes('00000000-0000-4000-8000-000000115031'), 2, 'the corrected month pushes once it comes within 30 days');
select is(pg_temp.months('00000000-0000-4000-8000-000000115031'), array[pg_temp.month(0), pg_temp.month(8)],
  'one push for each month');
-- The same month never queues twice: the alert closes (a count found none left, say) and opens again.
update public.alerts set resolved_at = now() where id = '00000000-0000-4000-8000-000000115051';
insert into public.alerts (id, clinic_id, kind, product_id, batch_id, threshold_days) values
  ('00000000-0000-4000-8000-000000115052', '00000000-0000-4000-8000-000000115011', 'expiring',
   '00000000-0000-4000-8000-000000115021', '00000000-0000-4000-8000-000000115031', 30);
select is(pg_temp.pushes('00000000-0000-4000-8000-000000115031'), 2, 'its alert opening again in the same month queues nothing');
update public.alerts set resolved_at = now() where id = '00000000-0000-4000-8000-000000115052';

-- Edit batch moves it back within 30 days: to last month, never pushed, queues one more; out again and back to this
-- month, pushed already, queues nothing.
select pg_temp.act_as('00000000-0000-4000-8000-000000115002');
select public.batch_upsert('00000000-0000-4000-8000-000000115021', '00000000-0000-4000-8000-000000115031',
  pg_temp.month(-1), 20, 'A112', '00000000-0000-4000-8000-000000115063');
reset role;
select is(pg_temp.pushes('00000000-0000-4000-8000-000000115031'), 3,
  'moving it back within 30 days to a month not pushed yet queues one more');
select pg_temp.act_as('00000000-0000-4000-8000-000000115002');
select public.batch_upsert('00000000-0000-4000-8000-000000115021', '00000000-0000-4000-8000-000000115031',
  pg_temp.month(8), 20, 'A112', '00000000-0000-4000-8000-000000115064');
select public.batch_upsert('00000000-0000-4000-8000-000000115021', '00000000-0000-4000-8000-000000115031',
  pg_temp.month(0), 20, 'A112', '00000000-0000-4000-8000-000000115065');
reset role;
select is(pg_temp.open_alerts('00000000-0000-4000-8000-000000115031'), 3, 'back to this month opens its alerts again');
select is(pg_temp.pushes('00000000-0000-4000-8000-000000115031'), 3, 'but queues nothing: this month was pushed already');
select is(pg_temp.months('00000000-0000-4000-8000-000000115031'),
  array[pg_temp.month(-1), pg_temp.month(0), pg_temp.month(8)], 'still one push per month');
-- A correction that stays within 30 days keeps the alert open, so nothing new reaches the bell or a phone.
select pg_temp.act_as('00000000-0000-4000-8000-000000115002');
select public.batch_upsert('00000000-0000-4000-8000-000000115021', '00000000-0000-4000-8000-000000115031',
  pg_temp.month(-2), 20, 'A112', '00000000-0000-4000-8000-000000115066');
reset role;
select is(pg_temp.pushes('00000000-0000-4000-8000-000000115031'), 3,
  'a correction that stays within 30 days keeps its alert and queues nothing');

-- Replays with the same idempotency key (the offline queue's retries, MS-108) answer the first action and move nothing.
select pg_temp.act_as('00000000-0000-4000-8000-000000115002');
select is(
  public.batch_upsert('00000000-0000-4000-8000-000000115021', '00000000-0000-4000-8000-000000115031',
    pg_temp.month(-1), 20, 'A112', '00000000-0000-4000-8000-000000115063'),
  (select id from public.stock_actions where idempotency_key = '00000000-0000-4000-8000-000000115063'),
  'a replay answers the first action');
select public.batch_upsert('00000000-0000-4000-8000-000000115021', '00000000-0000-4000-8000-000000115031',
  pg_temp.month(8), 20, 'A112', '00000000-0000-4000-8000-000000115064');
reset role;
select is((select expiry_month from public.batches where id = '00000000-0000-4000-8000-000000115031'), pg_temp.month(-2),
  'replays leave the batch''s month as it is');
select is(pg_temp.pushes('00000000-0000-4000-8000-000000115031'), 3, 'and queue no push');

-- The other pushes are as before: Out of stock and the delivery ready to review queue theirs, with no month.
select public.refresh_product('00000000-0000-4000-8000-000000115022');
select results_eq(
  $$ select kind::text, expiry_month from public.push_outbox where product_id = '00000000-0000-4000-8000-000000115022' $$,
  $$ values ('out_of_stock', null::date) $$,
  'Out of stock still queues its push, with no month');
insert into public.alerts (id, clinic_id, kind, invoice_id) values
  ('00000000-0000-4000-8000-000000115053', '00000000-0000-4000-8000-000000115011', 'invoice_ready', '00000000-0000-4000-8000-000000115041');
select results_eq(
  $$ select kind::text, expiry_month from public.push_outbox where invoice_id = '00000000-0000-4000-8000-000000115041' $$,
  $$ values ('invoice_ready', null::date) $$,
  'a delivery ready to review still queues its push, with no month');
update public.alerts set resolved_at = now() where id = '00000000-0000-4000-8000-000000115053';
insert into public.alerts (id, clinic_id, kind, invoice_id) values
  ('00000000-0000-4000-8000-000000115054', '00000000-0000-4000-8000-000000115011', 'invoice_ready', '00000000-0000-4000-8000-000000115041');
select is((select count(*)::integer from public.push_outbox where invoice_id = '00000000-0000-4000-8000-000000115041'), 1,
  'and still only once per delivery');

-- Bonding agent's batch expires this month too, the month Septocaine's pushed for: the key is the batch and its month.
select public.refresh_product('00000000-0000-4000-8000-000000115023');
select is(pg_temp.pushes('00000000-0000-4000-8000-000000115033'), 1, 'another batch expiring the same month pushes on its own');
-- A push queued before this fix whose batch has since moved to a later month is left with no month (see the
-- migration): it holds no month back.
update public.push_outbox set expiry_month = null where batch_id = '00000000-0000-4000-8000-000000115033';
update public.alerts set resolved_at = now() where batch_id = '00000000-0000-4000-8000-000000115033' and resolved_at is null;
select public.refresh_product('00000000-0000-4000-8000-000000115023');
select is(pg_temp.pushes('00000000-0000-4000-8000-000000115033'), 2, 'a push queued before this fix with no month holds no month back');

select * from finish();
rollback;
