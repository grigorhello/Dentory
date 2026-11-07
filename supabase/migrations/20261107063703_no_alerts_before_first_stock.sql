-- No alerts before a product's first stock (Claude's default as product owner, 2026-11-07, with the starting catalog,
-- supabase/catalogs). PRD §5: "To buy auto-add fires when a product becomes Low or Out of stock". A product nobody has
-- stocked yet (a catalog's product before the clinic's first count, one typed on New product before its first delivery)
-- never became either: it was born at 0. Until now refresh_product, at the nightly refresh (07:00 UTC), gave every such
-- product an Out of stock alert, its push at 7 AM and an automatic To buy line for its target, and a later count left
-- that line on To buy: 74 of each for a clinic that had just loaded the general-practice catalog.
-- - A product never stocked gets no Out of stock or Low alert, so no push, and no automatic To buy line. Never stocked:
--   no ledger row (never received, counted, adjusted, given an expiry with a quantity, or used from stock) and nothing
--   held now. Every stock change writes a ledger row and refreshes the product, so its first count, adjustment or
--   delivery brings the rule back as before; "nothing held" only matters for stock written straight into the tables,
--   as test fixtures do, which keeps its alerts. A count, adjustment or procedure that moves nothing writes no row (a
--   procedure takes nothing from a product at 0, 20261107033433_stock_never_negative.sql): such a product stays
--   quiet, and Add to buy still puts it on the list.
-- - Its status is unchanged: at 0 it reads Out of stock in Inventory and on its page, and the Low filter lists it.
-- - Missing expiry and Expiring alerts need stock, so they cannot reach such a product anyway.
-- - A product that once had stock and is used down to 0 raises its alert, push and To buy line as before.
-- Alerts the old rule opened for such products close here, so their pushes not yet sent are skipped (push_claim); the
-- To buy lines it added stay, since a clinic may be about to order them.

-- MS-128's refresh_product (20261019233000_to_buy_list.sql), unchanged but for v_stocked.
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
  v_stocked boolean;
begin
  select * into v_product from public.products where id = p_product_id;
  select * into v_stock from public.product_stock where product_id = p_product_id;
  select expiry_thresholds, time_zone into v_thresholds, v_time_zone from public.clinics where id = v_product.clinic_id;
  v_status := public.product_status_of(p_product_id);
  -- Stocked: it holds something, or a stock change was written for it once (transactions_product_at_idx).
  v_stocked := coalesce(v_stock.unopened, 0) <> 0 or coalesce(v_stock.open_count, 0) > 0
    or exists (select 1 from public.transactions t where t.product_id = p_product_id);

  perform engine.set_alert(v_product.clinic_id, 'out_of_stock', p_product_id, null, null,
    v_stocked and v_status = 'out_of_stock');
  perform engine.set_alert(v_product.clinic_id, 'low', p_product_id, null, null, v_stocked and v_status = 'low');
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

  if v_stocked and v_product.archived_at is null and v_status in ('out_of_stock', 'low')
     and not v_product.to_buy_dismissed
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

-- The Out of stock and Low alerts the old rule opened for products never stocked.
update public.alerts a set resolved_at = now()
from public.product_stock s
where s.product_id = a.product_id and a.kind in ('out_of_stock', 'low') and a.resolved_at is null
  and s.unopened = 0 and s.open_count = 0
  and not exists (select 1 from public.transactions t where t.product_id = a.product_id);
