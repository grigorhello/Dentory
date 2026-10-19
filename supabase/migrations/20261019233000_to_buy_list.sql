-- MS-128 · To buy list (PRD §6.6 and §5, Appendix B `order`, Appendix C `addOrder`; f25, f26).
-- Members change quantities and remove lines through the MS-105 policies; these functions read the list, add a
-- product with its suggested quantity, and mark lines ordered (Admin). Receiving marks lines Received in the
-- engine (MS-106). A line someone removes while its product is Low or Out of stock stays away until the product
-- goes back above its minimum and drops again.

-- Removed suggestions ---------------------------------------------------------------------------------------

alter table public.products add column to_buy_dismissed boolean not null default false;
comment on column public.products.to_buy_dismissed is
  'A To buy line was removed while the product was Low or Out of stock: no new one is added until it recovers.';

-- Set when a line still "to buy" is deleted (the swipe on To buy, or Undo of "Add to buy") while the product is
-- Low or Out of stock. Security definer: the product row is the admins' to write.
create function public.to_buy_items_dismiss()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.product_status_of(old.product_id) in ('low', 'out_of_stock') then
    update public.products set to_buy_dismissed = true where id = old.product_id;
  end if;
  return null;
end;
$$;

create trigger to_buy_items_dismiss
  after delete on public.to_buy_items
  for each row when (old.status = 'to_buy')
  execute function public.to_buy_items_dismiss();

-- The engine's refresh, unchanged but for To buy: a dismissed product gets no new line while it stays Low or Out
-- of stock, and is forgiven once it is above its minimum again.
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

  if v_product.archived_at is null and v_status in ('out_of_stock', 'low') and not v_product.to_buy_dismissed
     and not exists (select 1 from public.to_buy_items t where t.product_id = p_product_id and t.status in ('to_buy', 'ordered'))
  then
    insert into public.to_buy_items (clinic_id, product_id, qty, source)
    values (v_product.clinic_id, p_product_id, greatest(v_product.target - v_stock.quantity, 1), 'auto');
  else
    update public.to_buy_items set qty = greatest(v_product.target - v_stock.quantity, 1)
    where product_id = p_product_id and status = 'to_buy' and qty_edited = false;
  end if;
  if v_product.to_buy_dismissed and v_status not in ('out_of_stock', 'low') then
    update public.products set to_buy_dismissed = false where id = p_product_id;
  end if;

  return v_status;
end;
$$;

-- The list ----------------------------------------------------------------------------------------------------

-- Every line still to buy, in catalog order (the order the products joined the clinic, as f25 lists them), the
-- lines ordered and those received in the last 90 days, newest first, with the product's name, unit, supplier,
-- current stock and target. Security invoker, so RLS keeps each clinic to itself.
create function public.to_buy_list(p_clinic_id uuid)
returns table (
  id uuid,
  product_id uuid,
  name text,
  unit text,
  supplier text,
  quantity numeric,
  target numeric,
  qty numeric,
  qty_edited boolean,
  source text,
  status text,
  created_at timestamptz,
  ordered_at timestamptz,
  received_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    t.id, t.product_id, p.name, p.unit, p.supplier, coalesce(s.quantity, 0), p.target, t.qty, t.qty_edited,
    t.source::text, t.status::text, t.created_at, t.ordered_at, t.received_at
  from public.to_buy_items t
  join public.products p on p.id = t.product_id
  left join public.product_stock s on s.product_id = p.id
  where t.clinic_id = p_clinic_id
    and (t.status <> 'received' or t.received_at >= now() - interval '90 days')
  order by
    case t.status when 'to_buy' then 0 when 'ordered' then 1 else 2 end,
    case when t.status = 'to_buy' then p.created_at end,
    case when t.status = 'to_buy' then p.id end,
    coalesce(t.received_at, t.ordered_at) desc,
    lower(p.name), t.id;
$$;
revoke execute on function public.to_buy_list(uuid) from public, anon;
grant execute on function public.to_buy_list(uuid) to authenticated, service_role;

-- Add to To buy (sheet `addOrder`, both roles): the product joins with target − current, at least 1, as a manual
-- line. A product already on the list keeps its line, which comes back. Answers the line's id and quantity.
create function public.to_buy_add(p_clinic_id uuid, p_product_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_product public.products;
  v_quantity numeric;
  v_id uuid;
  v_qty numeric;
begin
  if not public.clinic_can_write(p_clinic_id) then
    raise exception 'The clinic is read-only until a payment method is added' using errcode = '42501';
  end if;
  select p.* into v_product from public.products p where p.id = p_product_id and p.clinic_id = p_clinic_id;
  if v_product.id is null or v_product.archived_at is not null then
    raise exception 'This product no longer exists.' using errcode = '22023';
  end if;
  select t.id, t.qty into v_id, v_qty
  from public.to_buy_items t where t.product_id = p_product_id and t.status = 'to_buy';
  if v_id is null then
    select coalesce(s.quantity, 0) into v_quantity from public.product_stock s where s.product_id = p_product_id;
    insert into public.to_buy_items (clinic_id, product_id, qty, source, added_by)
    values (p_clinic_id, p_product_id, greatest(v_product.target - coalesce(v_quantity, 0), 1), 'manual', auth.uid())
    returning id, qty into v_id, v_qty;
  end if;
  return jsonb_build_object('id', v_id, 'qty', v_qty);
end;
$$;
revoke execute on function public.to_buy_add(uuid, uuid) from public, anon;
grant execute on function public.to_buy_add(uuid, uuid) to authenticated, service_role;

-- Mark N as ordered (Admin): the chosen lines still to buy move to Ordered with today's date and the admin's name;
-- their quantity no longer follows stock. Answers how many moved.
create function public.to_buy_mark_ordered(p_clinic_id uuid, p_item_ids uuid[])
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_count integer;
begin
  if not public.is_admin(p_clinic_id) then
    raise exception 'Only an admin can mark items as ordered' using errcode = '42501';
  end if;
  if not public.clinic_can_write(p_clinic_id) then
    raise exception 'The clinic is read-only until a payment method is added' using errcode = '42501';
  end if;
  update public.to_buy_items t set status = 'ordered', ordered_at = now(), ordered_by = auth.uid()
  where t.clinic_id = p_clinic_id and t.id = any (coalesce(p_item_ids, '{}')) and t.status = 'to_buy';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke execute on function public.to_buy_mark_ordered(uuid, uuid[]) from public, anon;
grant execute on function public.to_buy_mark_ordered(uuid, uuid[]) to authenticated, service_role;
