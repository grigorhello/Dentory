-- MS-145 · Weekly email digest (PRD §8, f33's Email digest switch). Every Monday at 7 am in the clinic's time zone,
-- each active admin of a clinic with the digest on gets one email with what Home says needs attention: the To buy
-- count, the batches expiring within the clinic's expiry warning (the five soonest, with their days), the products
-- missing an expiry, and the procedures of the week before (Monday to Sunday at the clinic, cancelled ones left out).
-- The counts are Home's tiles (clinic_attention), so the email and the app agree.
--
-- Each hour pg_cron queues the clinics whose Monday morning has come (7 am to noon at the clinic, so a missed hour
-- catches up; one row per clinic and week in digest_sends) and, when one is waiting, asks the send_digest Edge
-- Function to send it. The function claims the rows (digest_claim), emails each admin through Resend and records what
-- went out (digest_finish). The claim reads the switch again, so turning it off before the send stops it; a read-only
-- clinic (MS-100 G5) gets none, and a digest still unsent 6 hours after it was queued is dropped rather than sent late.
-- As for send_push, the function's URL and key come from Vault (`project_url`, `service_role_key`), set by hand on
-- each hosted project; without them nothing is called.
--
-- New clinics start with the digest on; an admin turns it off in Clinic settings (decisions log, MS-145).

alter table public.clinics alter column email_digest set default true;

create table public.digest_sends (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  -- The Monday it is for, at the clinic.
  week date not null,
  -- Set while send_digest works on the row; a claim older than 10 minutes is retried.
  claimed_at timestamptz,
  sent_at timestamptz,
  -- The admins it reached.
  recipients integer,
  -- Why it never went out: the switch was turned off first, the clinic is read-only, or it waited too long.
  skipped text check (skipped in ('off', 'read_only', 'late')),
  unique (clinic_id, week)
);
-- Only the functions below touch it: no policy, so members read and write nothing.
alter table public.digest_sends enable row level security;
revoke all on public.digest_sends from anon, authenticated;

-- The clinics whose Monday morning has come at p_now (7 am to noon in their time zone), one row each for the week.
-- A time zone Postgres does not know is left out rather than failing the hour for every clinic. Answers how many
-- were queued.
create function engine.digest_queue(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  -- The local time reads the joined zone's name, so it is only ever worked out for a name Postgres knows.
  insert into public.digest_sends (clinic_id, week)
  select l.id, l.local_time::date
  from (
    select c.id, p_now at time zone z.name as local_time
    from public.clinics c
    join pg_catalog.pg_timezone_names z on z.name = c.time_zone
    where c.email_digest
  ) l
  where extract(isodow from l.local_time) = 1
    and extract(hour from l.local_time) between 7 and 11
  on conflict (clinic_id, week) do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke execute on function engine.digest_queue(timestamptz) from public, anon, authenticated;

-- What a clinic's digest says for the week starting p_week (a Monday at the clinic): Home's three counts, the window
-- (the largest expiry threshold), the five batches expiring soonest within it as the Expiring soon screen orders and
-- describes them, the procedures of the 7 days before p_week, and the active admins it goes to (their sign-in address
-- and name).
create function engine.digest_content(p_clinic_id uuid, p_week date)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'clinic_name', c.name,
    'week', p_week,
    'window', w.window_days,
    'to_buy', a.to_buy_count,
    'expiring', a.expiring_batch_count,
    'soonest', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', s.name, 'qty', s.qty, 'unit', s.unit, 'lot', s.lot, 'expiry_month', s.expiry_month, 'days', s.days
        )
        order by s.expiry_month, s.name, s.id
      )
      from (
        select b.id, p.name, p.unit, b.qty, b.lot, b.expiry_month,
               public.days_to_expiry(b.expiry_month, c.time_zone) as days
        from public.batches b
        join public.products p on p.id = b.product_id
        where b.clinic_id = c.id
          and p.archived_at is null
          and b.qty > 0
          and b.expiry_month is not null
          and public.days_to_expiry(b.expiry_month, c.time_zone) <= w.window_days
        order by b.expiry_month, p.name, b.id
        limit 5
      ) s
    ), '[]'::jsonb),
    'missing_expiry', a.missing_expiry_product_count,
    'procedures', (
      select count(*)::integer
      from public.procedure_events e
      where e.clinic_id = c.id
        and e.cancelled_at is null
        and e.started_at >= ((p_week - 7)::timestamp at time zone c.time_zone)
        and e.started_at < (p_week::timestamp at time zone c.time_zone)
    ),
    'recipients', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'email', coalesce(u.email::text, m.email),
          'name', coalesce(nullif(pr.full_name, ''), nullif(m.full_name, ''))
        )
        order by m.invited_at, m.id
      )
      from public.memberships m
      left join auth.users u on u.id = m.user_id
      left join public.profiles pr on pr.user_id = m.user_id
      where m.clinic_id = c.id and m.role = 'admin' and m.status = 'active'
    ), '[]'::jsonb)
  )
  from public.clinics c
  cross join lateral (select max(t) as window_days from unnest(c.expiry_thresholds) t) w
  join public.clinic_attention a on a.clinic_id = c.id
  where c.id = p_clinic_id;
$$;
revoke execute on function engine.digest_content(uuid, date) from public, anon, authenticated;

-- send_digest's claim: first drops what may no longer go out (the switch turned off, a read-only clinic, queued more
-- than 6 hours ago), then takes up to p_limit of the rest and answers each with its id and what its email says, as
-- one jsonb array (no PostgREST row limit applies).
create function public.digest_claim(p_limit integer default 20)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_digests jsonb;
begin
  update public.digest_sends d
  set skipped = case
      when not c.email_digest then 'off'
      when not coalesce(public.clinic_can_write(c.id), false) then 'read_only'
      else 'late'
    end
  from public.clinics c
  where c.id = d.clinic_id
    and d.sent_at is null and d.skipped is null
    and (
      not c.email_digest
      or not coalesce(public.clinic_can_write(c.id), false)
      or d.created_at < now() - interval '6 hours'
    );

  with due as (
    select d.id
    from public.digest_sends d
    where d.sent_at is null and d.skipped is null
      and (d.claimed_at is null or d.claimed_at < now() - interval '10 minutes')
    order by d.created_at, d.id
    limit least(greatest(coalesce(p_limit, 20), 1), 200)
    for update skip locked
  ),
  claimed as (
    update public.digest_sends d set claimed_at = now()
    from due
    where d.id = due.id
    returning d.id, d.clinic_id, d.week, d.created_at
  )
  select coalesce(
    jsonb_agg(jsonb_build_object('id', c.id) || engine.digest_content(c.clinic_id, c.week) order by c.created_at, c.id),
    '[]'::jsonb
  )
  into v_digests
  from claimed c;
  return v_digests;
end;
$$;
revoke execute on function public.digest_claim(integer) from public, anon, authenticated;
grant execute on function public.digest_claim(integer) to service_role;

-- What send_digest managed: each digest it sent and how many admins it reached. A row left out stays claimed and is
-- retried once its claim is 10 minutes old.
create function public.digest_finish(p_sent uuid[], p_recipients integer[])
returns void
language sql
security definer
set search_path = ''
as $$
  update public.digest_sends d
  set sent_at = now(), recipients = s.recipients
  from unnest(coalesce(p_sent, '{}'), coalesce(p_recipients, '{}')) as s (id, recipients)
  where d.id = s.id and d.sent_at is null;
$$;
revoke execute on function public.digest_finish(uuid[], integer[]) from public, anon, authenticated;
grant execute on function public.digest_finish(uuid[], integer[]) to service_role;

-- One clinic's digest as it would read this week, whatever the day and the switch, to try the email on a hosted
-- project (send_digest with a clinic id). Nothing is queued or recorded; null for an unknown clinic.
create function public.digest_preview(p_clinic_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select engine.digest_content(c.id, date_trunc('week', now() at time zone c.time_zone)::date)
  from public.clinics c
  where c.id = p_clinic_id;
$$;
revoke execute on function public.digest_preview(uuid) from public, anon, authenticated;
grant execute on function public.digest_preview(uuid) to service_role;

-- Each hour: queue the clinics whose Monday morning has come and, when a digest is waiting and the project has the
-- function's URL and key in Vault, ask send_digest to send.
create function engine.digest_dispatch()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_key text;
begin
  perform engine.digest_queue(now());
  if not exists (
    select 1 from public.digest_sends d
    where d.sent_at is null and d.skipped is null
      and (d.claimed_at is null or d.claimed_at < now() - interval '10 minutes')
  ) then
    return;
  end if;
  select s.decrypted_secret into v_url from vault.decrypted_secrets s where s.name = 'project_url';
  select s.decrypted_secret into v_key from vault.decrypted_secrets s where s.name = 'service_role_key';
  if v_url is null or v_key is null then
    return;
  end if;
  perform net.http_post(
    url := rtrim(v_url, '/') || '/functions/v1/send_digest',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
end;
$$;
revoke execute on function engine.digest_dispatch() from public, anon, authenticated;

select cron.schedule('weekly-digest', '0 * * * *', $$select engine.digest_dispatch()$$);
