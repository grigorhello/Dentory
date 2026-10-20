-- MS-133 · Activity: alerts and the bell (PRD §6.8, §5 Alerts; Appendix B `activity`; f8). The engine opens and
-- resolves alerts (MS-106, MS-107); this reads the open ones, one row per subject, and keeps each member's "seen"
-- marker behind Home's bell dot. Nothing here writes stock.

-- The open alerts of a clinic, newest first, one row per subject: an expiring batch has one open alert per
-- threshold it crossed (MS-100 D8) and is listed once, by the latest. Each row carries what its sentence needs: the
-- product's name, unit, tracking, stock and minimum; the batch's lot and month, and how many of the product's
-- batches are expiring (the lot is named when there are several); the invoice's supplier. A delivery waiting for
-- review is an admin's alert only, and an archived product's alerts are not listed. Security invoker: a member sees
-- only their clinic.
create function public.activity_alerts(p_clinic_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with open_alerts as (
    select a.*,
           row_number() over (
             partition by a.kind, a.product_id, a.batch_id, a.invoice_id
             order by a.opened_at desc, a.threshold_days
           ) as rank
    from public.alerts a
    where a.clinic_id = p_clinic_id and a.resolved_at is null
  ),
  listed as (
    select o.id, o.kind, o.opened_at, o.threshold_days,
           o.product_id, p.name, p.unit, p.tracking, p.minimum, s.quantity, s.unopened,
           o.batch_id, b.lot, b.expiry_month,
           (select count(distinct e.batch_id) from public.alerts e
             where e.product_id = o.product_id and e.kind = 'expiring' and e.resolved_at is null)::integer
             as expiring_batches,
           o.invoice_id, i.supplier
    from open_alerts o
    left join public.products p on p.id = o.product_id
    left join public.product_stock s on s.product_id = o.product_id
    left join public.batches b on b.id = o.batch_id
    left join public.invoices i on i.id = o.invoice_id
    where o.rank = 1
      and (o.product_id is null or p.archived_at is null)
      and (o.kind <> 'invoice_ready' or public.is_admin(p_clinic_id))
  )
  select coalesce(jsonb_agg(to_jsonb(l) order by l.opened_at desc, l.id), '[]'::jsonb) from listed l;
$$;
revoke execute on function public.activity_alerts(uuid) from public, anon;
grant execute on function public.activity_alerts(uuid) to authenticated, service_role;

-- Opening the Alerts segment: the member's "seen" marker moves to now, on the server's clock, so Home's bell loses
-- its dot until a newer alert opens. Security invoker under alert_reads' own-row policy. Answers the new marker.
create function public.alerts_mark_seen(p_clinic_id uuid)
returns timestamptz
language sql
volatile
security invoker
set search_path = ''
as $$
  insert into public.alert_reads (clinic_id, user_id, last_seen_at)
  values (p_clinic_id, auth.uid(), now())
  on conflict (clinic_id, user_id) do update set last_seen_at = excluded.last_seen_at
  returning last_seen_at;
$$;
revoke execute on function public.alerts_mark_seen(uuid) from public, anon;
grant execute on function public.alerts_mark_seen(uuid) to authenticated, service_role;
