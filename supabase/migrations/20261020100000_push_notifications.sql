-- MS-144 · Push notifications (PRD §8). The in-app alerts stay the source of truth; three of them are mirrored as a push
-- to the members' devices: Out of stock and Expiring within 30 days to every active member, Delivery ready to review to
-- admins only. A push opens what the alert row opens (MS-133): the product, or Receive delivery.
--
-- Opening an alert queues its push (push_outbox). Quiet bundling: one push per product per day, so a product that runs
-- out again within the day waits until the next day, and goes out only if it is still out of stock then; an expiring
-- batch pushes once. Quiet hours: nothing goes out between 9 pm and 7 am in the clinic's time zone; a push due then
-- waits for 7 am, so the nightly status job's expiring alerts reach phones in the morning. Each minute pg_cron asks the
-- send_push Edge Function to send what is due; it claims the rows
-- (push_claim), sends them through APNs and records the result (push_finish). The function's URL and key come from
-- Vault (`project_url`, `service_role_key`), set by hand on each hosted project; without them nothing is called.

create extension if not exists pg_net with schema extensions;

create table public.push_outbox (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  alert_id uuid not null references public.alerts (id) on delete cascade,
  kind public.alert_kind not null,
  product_id uuid,
  batch_id uuid,
  invoice_id uuid,
  -- The earliest moment it may go out: a day after the product's previous push, and within the clinic's waking hours.
  not_before timestamptz not null default now(),
  -- Set while send_push works on the row; a claim older than 10 minutes is retried.
  claimed_at timestamptz,
  sent_at timestamptz,
  -- Why it never went out: 'resolved' (the alert closed first), 'archived', 'stale' (undelivered for a day).
  skipped text check (skipped in ('resolved', 'archived', 'stale'))
);
create index push_outbox_due_idx on public.push_outbox (not_before) where sent_at is null and skipped is null;
create index push_outbox_product_idx on public.push_outbox (product_id, not_before) where skipped is null;
-- Only the functions below touch it: no policy, so members read and write nothing.
alter table public.push_outbox enable row level security;
revoke all on public.push_outbox from anon, authenticated;

-- The first moment from p_at within the clinic's waking hours, 7 am to 9 pm in its time zone: a push due in the night
-- waits for 7 am.
create function engine.push_waking_time(p_at timestamptz, p_time_zone text)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select case
    when l.local_at::time < time '07:00' then (l.local_at::date + time '07:00') at time zone z.tz
    when l.local_at::time >= time '21:00' then (l.local_at::date + 1 + time '07:00') at time zone z.tz
    else p_at
  end
  from (select coalesce(nullif(p_time_zone, ''), 'UTC') as tz) z
  cross join lateral (select p_at at time zone z.tz as local_at) l;
$$;
revoke execute on function engine.push_waking_time(timestamptz, text) from public, anon, authenticated;

-- Queues the push of an alert that just opened, when its kind is one PRD §8 mirrors.
create function engine.queue_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_not_before timestamptz := now();
begin
  if new.kind = 'expiring' then
    if new.threshold_days <> 30
       or exists (select 1 from public.push_outbox o where o.batch_id = new.batch_id and o.kind = 'expiring') then
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

  insert into public.push_outbox (clinic_id, alert_id, kind, product_id, batch_id, invoice_id, not_before)
  select new.clinic_id, new.id, new.kind, new.product_id, new.batch_id, new.invoice_id,
         engine.push_waking_time(coalesce(v_not_before, now()), c.time_zone)
  from public.clinics c
  where c.id = new.clinic_id;
  return null;
end;
$$;
revoke execute on function engine.queue_push() from public, anon, authenticated;

create trigger alerts_queue_push
after insert on public.alerts
for each row execute function engine.queue_push();

-- The due pushes, claimed for sending: title (the clinic), body (the alert's sentence, as Activity words it), the link
-- the app opens, and the device tokens of the members it goes to. Rows whose alert closed or whose product was
-- archived before they went out are skipped; a row still undelivered a day after it was due is dropped.
create function public.push_claim(p_limit integer default 50)
returns table (outbox_id uuid, title text, body text, link text, tokens text[])
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.push_outbox o set skipped = 'resolved'
  from public.alerts a
  where a.id = o.alert_id and a.resolved_at is not null and o.sent_at is null and o.skipped is null;
  update public.push_outbox o set skipped = 'archived'
  from public.products p
  where p.id = o.product_id and p.archived_at is not null and o.sent_at is null and o.skipped is null;
  update public.push_outbox o set skipped = 'stale'
  where o.sent_at is null and o.skipped is null and o.not_before < now() - interval '1 day';

  return query
  with due as (
    select o.id
    from public.push_outbox o
    where o.sent_at is null and o.skipped is null and o.not_before <= now()
      and (o.claimed_at is null or o.claimed_at < now() - interval '10 minutes')
    order by o.not_before, o.id
    limit least(greatest(coalesce(p_limit, 50), 1), 500)
    for update skip locked
  ),
  claimed as (
    update public.push_outbox o set claimed_at = now()
    from due
    where o.id = due.id
    returning o.*
  )
  select c.id,
         cl.name,
         case c.kind
           when 'out_of_stock' then p.name || ' is out of stock.'
           when 'expiring' then
             case
               when b.lot is not null and (
                 select count(distinct e.batch_id) from public.alerts e
                 where e.product_id = c.product_id and e.kind = 'expiring' and e.resolved_at is null
               ) > 1 then p.name || ' lot ' || b.lot
               else p.name
             end || ' ' ||
             case
               when public.days_to_expiry(b.expiry_month, cl.time_zone) < 0 then 'has expired'
               when public.days_to_expiry(b.expiry_month, cl.time_zone) = 0 then 'expires today'
               when public.days_to_expiry(b.expiry_month, cl.time_zone) = 1 then 'expires in 1 day'
               else 'expires in ' || public.days_to_expiry(b.expiry_month, cl.time_zone) || ' days'
             end || '.'
           else
             case
               when coalesce(btrim(i.supplier), '') = '' then 'A delivery is read and waiting for review.'
               else 'Delivery from ' || btrim(i.supplier) || ' is read and waiting for review.'
             end
         end,
         case when c.kind = 'invoice_ready' then 'dentory://delivery' else 'dentory://product/' || c.product_id end,
         array(
           select t.token
           from public.memberships m
           join public.push_tokens t on t.user_id = m.user_id
           where m.clinic_id = c.clinic_id and m.status = 'active'
             and (c.kind <> 'invoice_ready' or m.role = 'admin')
           order by t.token
         )
  from claimed c
  join public.clinics cl on cl.id = c.clinic_id
  left join public.products p on p.id = c.product_id
  left join public.batches b on b.id = c.batch_id
  left join public.invoices i on i.id = c.invoice_id
  order by c.not_before, c.id;
end;
$$;
revoke execute on function public.push_claim(integer) from public, anon, authenticated;
grant execute on function public.push_claim(integer) to service_role;

-- What send_push managed: the rows it sent, and the device tokens APNs no longer knows (deleted). A row left out stays
-- claimed and is retried once its claim is 10 minutes old.
create function public.push_finish(p_sent uuid[], p_dead_tokens text[] default '{}')
returns void
language sql
security definer
set search_path = ''
as $$
  update public.push_outbox set sent_at = now() where id = any (coalesce(p_sent, '{}')) and sent_at is null;
  delete from public.push_tokens where token = any (coalesce(p_dead_tokens, '{}'));
$$;
revoke execute on function public.push_finish(uuid[], text[]) from public, anon, authenticated;
grant execute on function public.push_finish(uuid[], text[]) to service_role;

-- This device's APNs token for the signed-in member. A device that changes hands keeps one row, now the new member's.
create function public.push_token_register(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform engine.fail('42501', 'Sign in first');
  end if;
  if p_token is null or p_token !~ '^[0-9a-f]{64,200}$' then
    perform engine.fail('22023', 'Not a device token');
  end if;
  insert into public.push_tokens (user_id, token)
  values (auth.uid(), p_token)
  on conflict (token) do update set user_id = excluded.user_id, updated_at = now();
end;
$$;
revoke execute on function public.push_token_register(text) from public, anon;
grant execute on function public.push_token_register(text) to authenticated, service_role;

-- Signing out on this device: its token stops receiving the member's pushes.
create function public.push_token_remove(p_token text)
returns void
language sql
security invoker
set search_path = ''
as $$
  delete from public.push_tokens where token = p_token and user_id = auth.uid();
$$;
revoke execute on function public.push_token_remove(text) from public, anon;
grant execute on function public.push_token_remove(text) to authenticated, service_role;

-- The APNs provider token send_push signs, shared by its instances: APNs refuses a token renewed more often than every
-- 20 minutes, and each cold instance would otherwise sign its own. Only send_push reads and writes it.
create table public.push_provider_tokens (
  key_id text primary key,
  token text not null,
  issued_at timestamptz not null default now()
);
alter table public.push_provider_tokens enable row level security;
revoke all on public.push_provider_tokens from anon, authenticated;

-- The shared token for this key while it is younger than 50 minutes; null when send_push should sign a new one.
create function public.push_provider_token(p_key_id text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select t.token from public.push_provider_tokens t
  where t.key_id = p_key_id and t.issued_at > now() - interval '50 minutes';
$$;
revoke execute on function public.push_provider_token(text) from public, anon, authenticated;
grant execute on function public.push_provider_token(text) to service_role;

-- Keeps a newly signed token, unless another instance kept a fresh one first; answers the token to use.
create function public.push_provider_token_save(p_key_id text, p_token text)
returns text
language sql
security definer
set search_path = ''
as $$
  with saved as (
    insert into public.push_provider_tokens as t (key_id, token, issued_at)
    values (p_key_id, p_token, now())
    on conflict (key_id) do update set token = excluded.token, issued_at = excluded.issued_at
      where t.issued_at <= now() - interval '50 minutes'
    returning t.token
  )
  select coalesce(
    (select s.token from saved s),
    (select t.token from public.push_provider_tokens t where t.key_id = p_key_id),
    p_token
  );
$$;
revoke execute on function public.push_provider_token_save(text, text) from public, anon, authenticated;
grant execute on function public.push_provider_token_save(text, text) to service_role;

-- Each minute: when something is due and the project has the function's URL and key in Vault, ask send_push to send.
create function engine.push_dispatch()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_key text;
begin
  if not exists (
    select 1 from public.push_outbox o
    where o.sent_at is null and o.skipped is null and o.not_before <= now()
      and (o.claimed_at is null or o.claimed_at < now() - interval '10 minutes')
  ) then
    return;
  end if;
  select s.decrypted_secret into v_url from vault.decrypted_secrets s where s.name = 'project_url';
  select s.decrypted_secret into v_key from vault.decrypted_secrets s where s.name = 'service_role_key';
  if v_url is null or v_key is null then
    return;
  end if;
  perform net.http_post(
    url := rtrim(v_url, '/') || '/functions/v1/send_push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
end;
$$;
revoke execute on function engine.push_dispatch() from public, anon, authenticated;

select cron.schedule('send-push', '* * * * *', $$select engine.push_dispatch()$$);
