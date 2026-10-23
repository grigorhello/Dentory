-- MS-132 · Expiring soon (PRD §6.7, Appendix B `expiring`; f27, f28): every batch with stock that expires within
-- the window, expired ones included, soonest first, with what it is worth. Mark disposed is the engine's
-- stock_dispose and its Undo the engine's undo_action (MS-106); nothing here writes.

-- The batches of a clinic expiring within p_window days (30, 60 or 90); null takes the clinic's largest expiry
-- threshold, the window Home's Expiring soon tile counts (MS-100 D8). A batch expires on the last day of its
-- month (days_to_expiry). Value is the batch quantity × the product's last unit cost, as clinic_attention's
-- value at risk counts it. Answers the window used and the batches; security invoker, so a member sees only
-- their clinic.
create function public.expiring_batches(p_clinic_id uuid, p_window integer default null)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with clinic as (
    select c.id, c.time_zone,
           coalesce(p_window, (select max(t) from unnest(c.expiry_thresholds) t)) as window_days
    from public.clinics c
    where c.id = p_clinic_id
  ),
  expiring as (
    select b.id, b.product_id, p.name, p.unit, p.tracking, b.qty, b.lot, b.expiry_month,
           (b.qty * coalesce(p.last_unit_cost, 0))::numeric(14, 2) as value
    from clinic c
    join public.batches b on b.clinic_id = c.id
    join public.products p on p.id = b.product_id
    where p.archived_at is null
      and b.qty > 0
      and b.expiry_month is not null
      and public.days_to_expiry(b.expiry_month, c.time_zone) <= c.window_days
  )
  select jsonb_build_object(
    'window', (select window_days from clinic),
    'batches', coalesce(
      (select jsonb_agg(to_jsonb(e) order by e.expiry_month, e.name, e.id) from expiring e),
      '[]'::jsonb
    )
  );
$$;
revoke execute on function public.expiring_batches(uuid, integer) from public, anon;
grant execute on function public.expiring_batches(uuid, integer) to authenticated, service_role;
