-- MS-144 fix (Refs #115, decided in the build thread on 2026-10-23) · An expiring batch pushes once per expiry month,
-- no longer once ever. MS-144 queued a batch's Expiring within 30 days push only if the batch had never had one, so a
-- batch whose month Edit batch (MS-119) moved later after its push stayed silent when the new month came within 30
-- days, while the alert and the bell showed it. Each expiring push now records the month its batch had when it was
-- queued, and a batch's 30-day alert queues a push unless one was queued for the batch in that month already. The
-- same month never queues twice, whether the alert closed and opened again or Edit batch moved the batch back to it.
-- A correction that keeps the batch within 30 days leaves its alert open, so nothing new is queued, as nothing new
-- reaches the bell; a push still waiting to go out says the corrected date. Everything else stays as MS-144 built it:
-- Out of stock and the delivery ready to review, one push per product per day, quiet hours, and the pushes push_claim
-- skips.

alter table public.push_outbox add column expiry_month date;
comment on column public.push_outbox.expiry_month is
  'The batch''s month when an expiring push was queued: a batch pushes once per month. Null for the other kinds.';

-- Pushes queued before this fix get the month their batch has now, unless that month was more than 30 days away on
-- the day the push was queued: such a batch has been moved to a later month since, so its push was for another
-- month, and leaving it without one lets the new month push once it comes within 30 days.
update public.push_outbox o
set expiry_month = b.expiry_month
from public.batches b
join public.clinics c on c.id = b.clinic_id
left join pg_catalog.pg_timezone_names z on z.name = c.time_zone
where o.kind = 'expiring' and b.id = o.batch_id
  and (b.expiry_month + interval '1 month' - interval '1 day')::date
      - (o.created_at at time zone coalesce(z.name, 'UTC'))::date <= 30;

-- The check below looks a batch's pushes up by month.
create index push_outbox_batch_month_idx on public.push_outbox (batch_id, expiry_month) where kind = 'expiring';

-- MS-144's trigger function, unchanged but for the expiring check and the month it records: only a push queued for
-- the batch in its current month holds a new one back, rather than any push the batch ever had.
create or replace function engine.queue_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_not_before timestamptz := now();
  v_expiry_month date;
begin
  if new.kind = 'expiring' then
    select b.expiry_month into v_expiry_month from public.batches b where b.id = new.batch_id;
    if new.threshold_days <> 30
       or exists (
         select 1 from public.push_outbox o
         where o.batch_id = new.batch_id and o.kind = 'expiring' and o.expiry_month = v_expiry_month
       ) then
      return null;
    end if;
  elsif new.kind = 'invoice_ready' then
    if exists (select 1 from public.push_outbox o where o.invoice_id = new.invoice_id) then
      return null;
    end if;
  elsif new.kind <> 'out_of_stock' then
    return null;
  end if;

  -- A day after the product's last push that went out or still will: one whose alert closed before it was sent never
  -- reaches a phone, so it holds nothing back.
  if new.product_id is not null then
    select greatest(now(), max(o.not_before) + interval '1 day') into v_not_before
    from public.push_outbox o
    join public.alerts a on a.id = o.alert_id
    where o.product_id = new.product_id and o.skipped is null
      and (o.sent_at is not null or a.resolved_at is null);
  end if;

  insert into public.push_outbox (clinic_id, alert_id, kind, product_id, batch_id, invoice_id, expiry_month, not_before)
  select new.clinic_id, new.id, new.kind, new.product_id, new.batch_id, new.invoice_id, v_expiry_month,
         engine.push_waking_time(coalesce(v_not_before, now()), c.time_zone)
  from public.clinics c
  where c.id = new.clinic_id;
  return null;
end;
$$;
