-- MS-150 · Performance and reliability under a full clinic's load (#121). What `make perf-report` measured on the
-- load-test clinic (`make seed-load`: 500 products, about 5,500 ledger rows over six months, read as its admin) and
-- what `make perf-concurrency` (eight clients starting procedures and opening bottles of the same products at once)
-- broke, fixed in the database. Function signatures, the view's columns and every answer stay as they were;
-- 48_performance_test.sql checks the rewritten view and policies against the definitions they replace.

-- Row level security in one pass per query ------------------------------------------------------------------------
-- Every read policy asked is_member(clinic_id) of each row it met: a security definer function, which Postgres does
-- not inline, at about 0.15 ms a row, so Inventory's 500 products with their batches, open bottles and categories
-- took 436 ms before the list's own work (20 ms). The rule is the same, but the caller's clinics are now read once per
-- query (an InitPlan) and each row's clinic compared with them, which an index on clinic_id can use too. The
-- admin-only tables do the same with the clinics the caller is an active admin of. The write policies, which meet the
-- one row being written, keep is_member and is_admin.
create function public.current_admin_clinic_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.clinic_id
  from public.memberships m
  where m.user_id = auth.uid() and m.status = 'active' and m.role = 'admin';
$$;
revoke execute on function public.current_admin_clinic_ids() from public, anon;
grant execute on function public.current_admin_clinic_ids() to authenticated, service_role;

alter policy clinics_read on public.clinics
  using (id = any (array(select public.current_clinic_ids())));
alter policy memberships_read on public.memberships
  using (clinic_id = any (array(select public.current_clinic_ids())));
alter policy categories_read on public.categories
  using (clinic_id = any (array(select public.current_clinic_ids())));
alter policy products_read on public.products
  using (clinic_id = any (array(select public.current_clinic_ids())));
alter policy batches_read on public.batches
  using (clinic_id = any (array(select public.current_clinic_ids())));
alter policy open_items_read on public.open_items
  using (clinic_id = any (array(select public.current_clinic_ids())));
alter policy transactions_read on public.transactions
  using (clinic_id = any (array(select public.current_clinic_ids())));
alter policy stock_actions_read on public.stock_actions
  using (clinic_id = any (array(select public.current_clinic_ids())));
alter policy procedure_templates_read on public.procedure_templates
  using (clinic_id = any (array(select public.current_clinic_ids())));
alter policy procedure_template_items_read on public.procedure_template_items
  using (clinic_id = any (array(select public.current_clinic_ids())));
alter policy procedure_events_read on public.procedure_events
  using (clinic_id = any (array(select public.current_clinic_ids())));
alter policy procedure_event_items_read on public.procedure_event_items
  using (clinic_id = any (array(select public.current_clinic_ids())));
alter policy procedure_event_openings_read on public.procedure_event_openings
  using (clinic_id = any (array(select public.current_clinic_ids())));
alter policy to_buy_items_read on public.to_buy_items
  using (clinic_id = any (array(select public.current_clinic_ids())));
alter policy alerts_read on public.alerts
  using (clinic_id = any (array(select public.current_clinic_ids())));

alter policy invoices_admin_read on public.invoices
  using (clinic_id = any (array(select public.current_admin_clinic_ids())));
alter policy invoice_lines_admin_read on public.invoice_lines
  using (clinic_id = any (array(select public.current_admin_clinic_ids())));
alter policy export_jobs_admin_read on public.export_jobs
  using (clinic_id = any (array(select public.current_admin_clinic_ids())));
alter policy clinic_billing_admin_read on public.clinic_billing
  using (clinic_id = any (array(select public.current_admin_clinic_ids())));
alter policy billing_invoices_admin_read on public.billing_invoices
  using (clinic_id = any (array(select public.current_admin_clinic_ids())));

-- product_stock, product by product ---------------------------------------------------------------------------------
-- The view summed every batch and counted every open bottle it could see, grouped by product, and joined that to the
-- products, so a caller that wanted one product (refresh_product after every stock change, product_detail, the
-- alerts) paid for the clinic's 500, and a nested loop over it paid again per row. Each product's batches and open
-- bottles are now summed through its own index. Same columns, same types, same figures, still read as the caller.
create or replace view public.product_stock
with (security_invoker = true)
as
select
  p.id as product_id,
  p.clinic_id,
  p.tracking,
  coalesce(b.unopened, 0)::numeric(12, 2) as unopened,
  coalesce(o.open_count, 0)::integer as open_count,
  (coalesce(b.unopened, 0) + case when p.tracking = 'multi_use' then coalesce(o.open_count, 0) else 0 end)
    ::numeric(12, 2) as quantity,
  greatest(coalesce(b.missing_expiry_qty, 0), 0)::numeric(12, 2) as missing_expiry_qty,
  b.soonest_expiry
from public.products p
cross join lateral (
  select
    sum(x.qty) as unopened,
    sum(x.qty) filter (where x.expiry_month is null) as missing_expiry_qty,
    min(x.expiry_month) filter (where x.qty > 0) as soonest_expiry
  from public.batches x
  where x.product_id = p.id
) b
cross join lateral (
  select count(*) as open_count
  from public.open_items x
  where x.product_id = p.id and x.finished_at is null
) o;

-- The indexes the stock changes and the screens were missing ---------------------------------------------------------
-- After every stock change refresh_product looks up the product's open alerts by kind and its To buy line, ordered or
-- not, and Activity's Alerts counts each product's open expiry alerts; editing or cancelling a procedure reads back
-- what it took of each product, and putting a bottle back the ledger row that opened it. Each of these read the
-- clinic's whole table: for the bottle, all 5,500 ledger rows. The batches are read by clinic for Expiring soon and the
-- value figures, now that the policy above can use an index.
create index alerts_product_open_idx on public.alerts (product_id, kind) where resolved_at is null;
create index to_buy_items_product_idx on public.to_buy_items (product_id, status);
create index transactions_ref_idx on public.transactions (ref_id);
create index transactions_open_item_idx on public.transactions (open_item_id) where open_item_id is not null;
create index batches_clinic_idx on public.batches (clinic_id);

-- A clinic's stock changes, one at a time ---------------------------------------------------------------------------
-- A stock change locks each product it changes as it reaches it: a procedure in its template's order, a count in its
-- list's order. Two procedures sharing supplies in another order, or a procedure and a bottle opened from its product,
-- then each held a row the other wanted, and Postgres ended one with a deadlock: with eight clients starting
-- procedures at once, 154 of 160 starts failed. Every change now takes its clinic's lock first, in the first engine
-- step each one makes (begin_action, lock_product, lock_product_row), so a clinic's changes wait in turn for the
-- milliseconds each takes and never hold rows another wants; clinics never wait for each other. A change that locks a
-- row of its own first (the procedure it edits, the action it undoes, the invoice it confirms) waits for that row
-- before the lock, so it cannot hold the lock while waiting for it. Mark as ordered and a clinic setting that refreshes
-- every product take the same lock, since they write the To buy lines and alerts each stock change refreshes.
create function engine.stock_lock(p_clinic_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtext('stock_lock'), hashtext(p_clinic_id::text));
end;
$$;
revoke execute on function engine.stock_lock(uuid) from public, anon, authenticated;

-- MS-106's function, unchanged but for the clinic's lock before the action is written.
create or replace function engine.begin_action(
  p_clinic_id uuid, p_key uuid, p_kind text, out o_action_id uuid, out o_replay boolean
)
language plpgsql
set search_path = ''
as $$
begin
  if p_key is null then
    perform engine.fail('22023', 'an idempotency key is required');
  end if;
  perform engine.stock_lock(p_clinic_id);
  insert into public.stock_actions (clinic_id, idempotency_key, kind, by_user)
  values (p_clinic_id, p_key, p_kind, auth.uid())
  on conflict (clinic_id, idempotency_key) do nothing
  returning id into o_action_id;
  if o_action_id is null then
    select id into o_action_id from public.stock_actions where clinic_id = p_clinic_id and idempotency_key = p_key;
    o_replay := true;
  else
    o_replay := false;
  end if;
end;
$$;

-- Locks the product row for the rest of the transaction and returns it, after its clinic's lock (MS-106's function,
-- unchanged but for that).
create or replace function engine.lock_product(p_product_id uuid)
returns public.products
language plpgsql
set search_path = ''
as $$
declare
  v_product public.products;
begin
  perform engine.stock_lock(p.clinic_id) from public.products p where p.id = p_product_id;
  select * into v_product from public.products where id = p_product_id for update;
  if not found then
    perform engine.fail('22023', 'unknown product');
  end if;
  if v_product.archived_at is not null then
    perform engine.fail('22023', 'the product is archived');
  end if;
  return v_product;
end;
$$;

-- The same, archived or not (MS-117's function, unchanged but for the clinic's lock).
create or replace function engine.lock_product_row(p_product_id uuid)
returns public.products
language plpgsql
set search_path = ''
as $$
declare
  v_product public.products;
begin
  perform engine.stock_lock(p.clinic_id) from public.products p where p.id = p_product_id;
  select * into v_product from public.products where id = p_product_id for update;
  if not found then
    perform engine.fail('22023', 'unknown product');
  end if;
  return v_product;
end;
$$;

-- MS-128's Mark N as ordered, unchanged but for the clinic's lock before the lines move. It runs as the caller, who
-- cannot reach the engine schema, so it takes engine.stock_lock's lock itself.
create or replace function public.to_buy_mark_ordered(p_clinic_id uuid, p_item_ids uuid[])
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
  perform pg_advisory_xact_lock(hashtext('stock_lock'), hashtext(p_clinic_id::text));
  update public.to_buy_items t set status = 'ordered', ordered_at = now(), ordered_by = auth.uid()
  where t.clinic_id = p_clinic_id and t.id = any (coalesce(p_item_ids, '{}')) and t.status = 'to_buy';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- MS-139's settings save, unchanged but for the clinic's lock before anything is written: a new expiry warning or
-- time zone refreshes every product of the clinic.
create or replace function public.clinic_settings_save(
  p_clinic_id uuid,
  p_name text,
  p_city text,
  p_country text,
  p_currency text,
  p_time_zone text,
  p_expiry_thresholds integer[],
  p_email_digest boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_country text := upper(btrim(coalesce(p_country, '')));
  v_currency text := upper(btrim(coalesce(p_currency, '')));
  v_before public.clinics;
begin
  if not coalesce(public.is_admin(p_clinic_id), false) then
    raise exception 'Only an admin can change clinic settings' using errcode = '42501';
  end if;
  if not coalesce(public.clinic_can_write(p_clinic_id), false) then
    raise exception 'The clinic is read-only until a payment method is added' using errcode = '42501';
  end if;
  if length(v_name) < 1 then
    raise exception 'Enter the clinic name' using errcode = '22023', hint = 'name';
  end if;
  if length(v_name) > 120 then
    raise exception 'Keep the clinic name to 120 characters' using errcode = '22023', hint = 'name';
  end if;
  if v_country !~ '^[A-Z]{2}$' then
    raise exception 'Choose a country' using errcode = '22023', hint = 'country';
  end if;
  if v_currency !~ '^[A-Z]{3}$' then
    raise exception 'Choose a currency' using errcode = '22023', hint = 'currency';
  end if;
  if p_time_zone is null or not exists (select 1 from pg_catalog.pg_timezone_names z where z.name = p_time_zone) then
    raise exception 'Choose a time zone' using errcode = '22023', hint = 'timeZone';
  end if;
  if p_expiry_thresholds is null
     or p_expiry_thresholds not in ('{30,60,90}'::integer[], '{60,90}'::integer[], '{90}'::integer[]) then
    raise exception 'Choose an expiry warning' using errcode = '22023', hint = 'expiryWarning';
  end if;

  perform engine.stock_lock(p_clinic_id);
  select * into v_before from public.clinics where id = p_clinic_id;
  update public.clinics
  set name = v_name,
      city = nullif(btrim(coalesce(p_city, '')), ''),
      country = v_country,
      currency = v_currency,
      time_zone = p_time_zone,
      expiry_thresholds = p_expiry_thresholds,
      email_digest = coalesce(p_email_digest, email_digest)
  where id = p_clinic_id;

  if v_before.expiry_thresholds is distinct from p_expiry_thresholds
     or v_before.time_zone is distinct from p_time_zone then
    perform public.refresh_product(p.id)
    from public.products p
    where p.clinic_id = p_clinic_id and p.archived_at is null;
  end if;
end;
$$;
