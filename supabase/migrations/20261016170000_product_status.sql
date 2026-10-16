-- MS-107 · Product status, attention counts and values (PRD §5; MS-100 D8, G3).
-- A batch expires on the last day of its month; days left count from today in the clinic's time zone.
-- The status rule lives in one function; the engine's refresh, the product_status view and the daily
-- cron all use it. The Swift mirror (Core/Domain/ProductStatus.swift) follows the same table of cases.

-- Last day of the batch's month minus today in the clinic's time zone.
create function public.days_to_expiry(p_expiry_month date, p_time_zone text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when p_expiry_month is null then null
    else (p_expiry_month + interval '1 month' - interval '1 day')::date - (now() at time zone p_time_zone)::date
  end;
$$;
grant execute on function public.days_to_expiry(date, text) to authenticated, service_role;

-- The rule, given the numbers (so the same cases test it and the Swift mirror).
create function public.evaluate_product_status(
  p_tracking public.tracking_mode, p_quantity numeric, p_unopened numeric, p_minimum numeric,
  p_missing_expiry_qty numeric, p_days_to_soonest_expiry integer, p_largest_threshold integer
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_quantity <= 0 then 'out_of_stock'
    when (p_tracking = 'multi_use' and p_unopened <= p_minimum) or (p_tracking = 'countable' and p_quantity <= p_minimum) then 'low'
    when p_days_to_soonest_expiry is not null and p_days_to_soonest_expiry <= p_largest_threshold then 'expiring'
    when p_missing_expiry_qty > 0 then 'missing_expiry'
    else 'healthy'
  end;
$$;
grant execute on function public.evaluate_product_status(public.tracking_mode, numeric, numeric, numeric, numeric, integer, integer) to authenticated, service_role;

-- The engine's product_status(uuid) becomes product_status_of(uuid) so the view can take the name.
alter function public.product_status(uuid) rename to product_status_of;
create or replace function public.product_status_of(p_product_id uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select public.evaluate_product_status(
    p.tracking, s.quantity, s.unopened, p.minimum, s.missing_expiry_qty,
    (select min(public.days_to_expiry(b.expiry_month, c.time_zone)) from public.batches b where b.product_id = p.id and b.qty > 0 and b.expiry_month is not null),
    (select max(t) from unnest(c.expiry_thresholds) t)
  )
  from public.products p
  join public.product_stock s on s.product_id = p.id
  join public.clinics c on c.id = p.clinic_id
  where p.id = p_product_id;
$$;

-- One row per product: status, stock figures, days to the soonest expiry and value (PRD §5).
create view public.product_status
with (security_invoker = true)
as
select
  p.id as product_id,
  p.clinic_id,
  public.evaluate_product_status(p.tracking, s.quantity, s.unopened, p.minimum, s.missing_expiry_qty, e.days, th.largest) as status,
  s.quantity,
  s.unopened,
  s.open_count,
  s.missing_expiry_qty,
  e.days as days_to_soonest_expiry,
  (s.quantity * coalesce(p.last_unit_cost, 0))::numeric(14, 2) as value
from public.products p
join public.product_stock s on s.product_id = p.id
join public.clinics c on c.id = p.clinic_id
cross join lateral (select max(t) as largest from unnest(c.expiry_thresholds) t) th
left join lateral (
  select min(public.days_to_expiry(b.expiry_month, c.time_zone)) as days
  from public.batches b where b.product_id = p.id and b.qty > 0 and b.expiry_month is not null
) e on true;
grant select on public.product_status to authenticated, service_role;

-- The Home tiles and value tiles, one row per clinic (PRD §6.2).
create view public.clinic_attention
with (security_invoker = true)
as
select
  c.id as clinic_id,
  (select count(*) from public.to_buy_items t where t.clinic_id = c.id and t.status = 'to_buy')::integer as to_buy_count,
  (select count(*) from public.batches b join public.products p on p.id = b.product_id
     where b.clinic_id = c.id and p.archived_at is null and b.qty > 0 and b.expiry_month is not null
       and public.days_to_expiry(b.expiry_month, c.time_zone) <= (select max(t) from unnest(c.expiry_thresholds) t))::integer as expiring_batch_count,
  (select count(*) from public.product_status ps join public.products p on p.id = ps.product_id
     where ps.clinic_id = c.id and p.archived_at is null and ps.missing_expiry_qty > 0)::integer as missing_expiry_product_count,
  (select coalesce(sum(ps.value), 0) from public.product_status ps join public.products p on p.id = ps.product_id
     where ps.clinic_id = c.id and p.archived_at is null)::numeric(14, 2) as inventory_value,
  (select coalesce(sum(b.qty * coalesce(p.last_unit_cost, 0)), 0) from public.batches b join public.products p on p.id = b.product_id
     where b.clinic_id = c.id and p.archived_at is null and b.qty > 0 and b.expiry_month is not null
       and public.days_to_expiry(b.expiry_month, c.time_zone) <= 90)::numeric(14, 2) as value_at_risk_90
from public.clinics c;
grant select on public.clinic_attention to authenticated, service_role;

-- The engine's refresh now reads the status through the renamed function and the month-end rule.
create or replace function public.refresh_product(p_product_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product public.products;
  v_stock public.product_stock;
  v_status text;
  v_thresholds int[];
  v_time_zone text;
  v_batch record;
  v_threshold int;
begin
  select * into v_product from public.products where id = p_product_id;
  select * into v_stock from public.product_stock where product_id = p_product_id;
  select expiry_thresholds, time_zone into v_thresholds, v_time_zone from public.clinics where id = v_product.clinic_id;
  v_status := public.product_status_of(p_product_id);

  perform engine.set_alert(v_product.clinic_id, 'out_of_stock', p_product_id, null, null, v_status = 'out_of_stock');
  perform engine.set_alert(v_product.clinic_id, 'low', p_product_id, null, null, v_status = 'low');
  perform engine.set_alert(v_product.clinic_id, 'missing_expiry', p_product_id, null, null, v_stock.missing_expiry_qty > 0);

  update public.alerts a set resolved_at = now()
  where a.product_id = p_product_id and a.kind = 'expiring' and a.resolved_at is null
    and not exists (
      select 1 from public.batches b
      where b.id = a.batch_id and b.qty > 0 and b.expiry_month is not null
        and public.days_to_expiry(b.expiry_month, v_time_zone) <= a.threshold_days
        and a.threshold_days = any (v_thresholds)
    );
  for v_batch in
    select id, expiry_month from public.batches
    where product_id = p_product_id and qty > 0 and expiry_month is not null
  loop
    foreach v_threshold in array v_thresholds loop
      if public.days_to_expiry(v_batch.expiry_month, v_time_zone) <= v_threshold then
        insert into public.alerts (clinic_id, kind, product_id, batch_id, threshold_days)
        values (v_product.clinic_id, 'expiring', p_product_id, v_batch.id, v_threshold)
        on conflict do nothing;
      end if;
    end loop;
  end loop;

  if v_product.archived_at is null and v_status in ('out_of_stock', 'low')
     and not exists (select 1 from public.to_buy_items t where t.product_id = p_product_id and t.status in ('to_buy', 'ordered'))
  then
    insert into public.to_buy_items (clinic_id, product_id, qty, source)
    values (v_product.clinic_id, p_product_id, greatest(v_product.target - v_stock.quantity, 1), 'auto');
  else
    update public.to_buy_items set qty = greatest(v_product.target - v_stock.quantity, 1)
    where product_id = p_product_id and status = 'to_buy' and qty_edited = false;
  end if;

  return v_status;
end;
$$;

-- Time passing changes status without any transaction: re-evaluate every product once a day.
create function public.refresh_all_products()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_count integer := 0;
begin
  for v_id in select id from public.products where archived_at is null loop
    perform public.refresh_product(v_id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke execute on function public.refresh_all_products() from public, anon, authenticated;

create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('refresh-product-status', '0 7 * * *', $$select public.refresh_all_products()$$);
