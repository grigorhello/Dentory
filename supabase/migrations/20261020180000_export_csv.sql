-- MS-143 · Export CSV (PRD §6.9 Export CSV). An admin asks for the clinic's data; the export_csv Edge Function writes
-- products.csv, batches.csv and transactions.csv (UTF-8 with a byte order mark, so Excel reads the accents; dates in
-- ISO 8601), zips them into the private exports bucket and emails the admin a signed link valid 7 days. One export
-- per clinic every 10 minutes. Only the service role (the function) reads these functions and the bucket.

insert into storage.buckets (id, name, public)
values ('exports', 'exports', false)
on conflict (id) do nothing;

-- Jobs now start through export_job_start only, which holds the 10 minute limit.
drop policy export_jobs_admin_insert on public.export_jobs;
revoke insert on public.export_jobs from authenticated;

-- Starts an export for the admin p_user_id: a running job, the address the link goes to, the clinic's name, and
-- today's date and the time at the clinic. A read-only clinic may export: its data stays its own.
create function public.export_job_start(p_clinic_id uuid, p_user_id uuid)
returns table (job_id uuid, email text, clinic_name text, day text, local_time text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_email text;
  v_recent_by uuid;
  v_recent_name text;
  v_recent_email text;
  v_job uuid;
begin
  select m.email into v_member_email
  from public.memberships m
  where m.clinic_id = p_clinic_id and m.user_id = p_user_id and m.role = 'admin' and m.status = 'active';
  if v_member_email is null then
    perform engine.fail('42501', 'Only an admin can export the clinic''s data');
  end if;
  -- One start at a time per clinic: a second call waits here, then sees the first one's job.
  perform pg_advisory_xact_lock(hashtext('export_job_start'), hashtext(p_clinic_id::text));
  select j.requested_by into v_recent_by
  from public.export_jobs j
  where j.clinic_id = p_clinic_id and j.status <> 'failed' and j.created_at > now() - interval '10 minutes'
  order by j.created_at desc
  limit 1;
  if found then
    if v_recent_by = p_user_id then
      perform engine.fail('22023', 'An export started less than 10 minutes ago. It is on its way to your email.');
    end if;
    -- Another admin's export went to their address: say whose, and where.
    select coalesce(u.email::text, m.email), coalesce(nullif(pr.full_name, ''), nullif(m.full_name, ''))
    into v_recent_email, v_recent_name
    from public.memberships m
    left join auth.users u on u.id = m.user_id
    left join public.profiles pr on pr.user_id = m.user_id
    where m.clinic_id = p_clinic_id and m.user_id = v_recent_by;
    perform engine.fail('22023', format(
      '%s started an export less than 10 minutes ago. It goes to %s.',
      coalesce(v_recent_name, 'Another admin'), coalesce(v_recent_email, 'their email')
    ));
  end if;
  insert into public.export_jobs (clinic_id, requested_by, status)
  values (p_clinic_id, p_user_id, 'running')
  returning id into v_job;
  return query
  select v_job, coalesce((select u.email::text from auth.users u where u.id = p_user_id), v_member_email), c.name,
         to_char(now() at time zone c.time_zone, 'YYYY-MM-DD'),
         to_char(now() at time zone c.time_zone, 'YYYY-MM-DD"T"HH24:MI:SS')
  from public.clinics c
  where c.id = p_clinic_id;
end;
$$;
revoke execute on function public.export_job_start(uuid, uuid) from public, anon, authenticated;
grant execute on function public.export_job_start(uuid, uuid) to service_role;

-- The export went out (its zip's path), or failed (no path), which frees the next one at once.
create function public.export_job_finish(p_job_id uuid, p_file_path text)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.export_jobs
  set status = (case when p_file_path is null then 'failed' else 'done' end)::public.export_status,
      file_path = p_file_path,
      finished_at = now()
  where id = p_job_id;
$$;
revoke execute on function public.export_job_finish(uuid, text) from public, anon, authenticated;
grant execute on function public.export_job_finish(uuid, text) to service_role;

-- products.csv: every product, archived ones last, with its stock and status as the app shows them. The three row
-- functions are read through export_data.
create function public.export_products(p_clinic_id uuid)
returns table (
  name text, category text, unit text, pack_unit text, pack_size integer, tracking text, minimum numeric,
  target numeric, supplier text, location text, quantity numeric, unopened numeric, open integer,
  last_unit_cost numeric, status text, archived date
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.name, c.name, p.unit, p.pack_unit, p.pack_size,
         case p.tracking when 'multi_use' then 'Multi-use' else 'Countable' end,
         p.minimum, p.target, p.supplier, p.location,
         coalesce(s.quantity, 0), coalesce(s.unopened, 0), coalesce(s.open_count, 0), p.last_unit_cost,
         case public.product_status_of(p.id)
           when 'out_of_stock' then 'Out of stock'
           when 'low' then 'Low'
           when 'expiring' then 'Expiring'
           when 'missing_expiry' then 'Missing expiry'
           else 'Healthy'
         end,
         (p.archived_at at time zone cl.time_zone)::date
  from public.products p
  join public.clinics cl on cl.id = p.clinic_id
  left join public.categories c on c.id = p.category_id
  left join public.product_stock s on s.product_id = p.id
  where p.clinic_id = p_clinic_id
  order by p.archived_at is not null, lower(p.name), p.id;
$$;
revoke execute on function public.export_products(uuid) from public, anon, authenticated;

-- batches.csv: the batches holding stock (or short of it), by product and expiry.
create function public.export_batches(p_clinic_id uuid)
returns table (product text, expiry_month text, lot text, qty numeric)
language sql
stable
security definer
set search_path = ''
as $$
  select p.name, to_char(b.expiry_month, 'YYYY-MM'), b.lot, b.qty
  from public.batches b
  join public.products p on p.id = b.product_id
  where b.clinic_id = p_clinic_id and b.qty <> 0
  order by lower(p.name), b.expiry_month nulls last, b.lot nulls last, b.id;
$$;
revoke execute on function public.export_batches(uuid) from public, anon, authenticated;

-- transactions.csv: the whole ledger, oldest first, at the clinic's local time.
create function public.export_transactions(p_clinic_id uuid)
returns table (
  date text, type text, product text, delta numeric, before numeric, after numeric, "user" text,
  reference text, reason text, note text
)
language sql
stable
security definer
set search_path = ''
as $$
  select to_char(t.at at time zone cl.time_zone, 'YYYY-MM-DD HH24:MI'),
         initcap(replace(t.type::text, '_', ' ')),
         p.name, t.delta, t.qty_before, t.qty_after,
         coalesce(nullif(pr.full_name, ''), nullif(m.full_name, ''), m.email, ''),
         coalesce(t.ref_label, initcap(replace(t.ref_type::text, '_', ' '))),
         t.reason, t.note
  from public.transactions t
  join public.clinics cl on cl.id = t.clinic_id
  join public.products p on p.id = t.product_id
  left join public.memberships m on m.clinic_id = t.clinic_id and m.user_id = t.by_user
  left join public.profiles pr on pr.user_id = t.by_user
  where t.clinic_id = p_clinic_id
  order by t.at, t.id;
$$;
revoke execute on function public.export_transactions(uuid) from public, anon, authenticated;

-- The three files' rows from one snapshot, so the ledger ends where the stock stands, in one jsonb value, which the
-- API's row limit (max_rows) does not cut short however long the ledger is.
create function public.export_data(p_clinic_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'products', (select coalesce(jsonb_agg(to_jsonb(r) - 'ordinality' order by r.ordinality), '[]'::jsonb)
                 from public.export_products(p_clinic_id) with ordinality r),
    'batches', (select coalesce(jsonb_agg(to_jsonb(r) - 'ordinality' order by r.ordinality), '[]'::jsonb)
                from public.export_batches(p_clinic_id) with ordinality r),
    'transactions', (select coalesce(jsonb_agg(to_jsonb(r) - 'ordinality' order by r.ordinality), '[]'::jsonb)
                     from public.export_transactions(p_clinic_id) with ordinality r)
  );
$$;
revoke execute on function public.export_data(uuid) from public, anon, authenticated;
grant execute on function public.export_data(uuid) to service_role;
