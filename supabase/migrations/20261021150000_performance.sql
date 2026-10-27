-- MS-150 · Performance and reliability under a full clinic's load (#121). What `make perf-report` measured on the
-- load-test clinic (`make seed-load`: 500 products, about 5,500 ledger rows over six months, read as its admin) and
-- what `make perf-concurrency` (eight clients starting procedures and opening bottles of the same products at once)
-- broke, fixed in the database. Function signatures, the view's columns and every answer stay as they were;
-- 49_performance_test.sql checks the rewritten view and policies against the definitions they replace.

-- Row level security in one pass per query ------------------------------------------------------------------------
-- Every read policy asked is_member(clinic_id) of each row it met: a security definer function, which Postgres does not
-- inline, at about 0.15 ms a row, so Inventory's 500 products with their batches, open bottles and categories took
-- 383 ms (p50), of which the list's own work is 22 ms. The rule is the same, but the caller's clinics are now read once
-- per query (an InitPlan) and each row's clinic compared with them, which an index on clinic_id can use too. The
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
-- then each held a row the other wanted, and Postgres ended one with a deadlock: with eight clients starting procedures
-- and opening bottles at once, 117 of 126 starts failed. Every change now takes its clinic's lock first, in the first
-- engine step each one makes (begin_action, lock_product, lock_product_row), so a clinic's changes wait in turn for the
-- milliseconds each takes; clinics never wait for each other. A few lock a row before the clinic's lock: the
-- procedure edited or cancelled, the action undone and a delivery's invoice with it, the invoice confirmed and the
-- invoice a receipt names. The rule that keeps them free of deadlocks: a row locked before the clinic's lock is never
-- locked after it by another change, so the change holding the lock never waits for one that waits for the lock
-- (undo_action and stock_receive, re-created at the end, keep it). Mark as ordered and a clinic setting that refreshes
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

-- Undo locks a delivery's invoice before the clinic's lock ----------------------------------------------------------
-- Undo of a delivery took the clinic's lock in begin_action and only then locked the invoice, in
-- engine.invoice_confirm_undo, while invoice_confirm locks the invoice and then the clinic's lock: a confirmation
-- retried while its Undo ran, and that Undo, could each hold what the other waited for. MS-131's undo_action
-- (20261021100000_invoice_confirm.sql), unchanged but for the invoice of a delivery, locked after the action and before
-- the clinic's lock.
create or replace function public.undo_action(p_action_id uuid, p_idempotency_key uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_original public.stock_actions;
  v_action record;
  v_row public.transactions;
  v_label text;
  v_undated uuid;
begin
  select * into v_original from public.stock_actions where id = p_action_id for update;
  if not found then perform engine.fail('22023', 'unknown action'); end if;
  perform engine.assert_member(v_original.clinic_id);
  if v_original.by_user <> auth.uid() then perform engine.fail('42501', 'only the person who did it can undo it'); end if;
  if v_original.kind not in ('adjust', 'receive', 'dispose', 'invoice_confirm') then
    perform engine.fail('22023', 'this action cannot be undone');
  end if;
  if v_original.kind = 'invoice_confirm' then
    perform 1 from public.invoices i where i.confirm_action_id = p_action_id for update;
  end if;
  v_action := engine.begin_action(v_original.clinic_id, p_idempotency_key, 'undo');
  if v_action.o_replay then return v_action.o_action_id; end if;
  if v_original.undone_by_action_id is not null then perform engine.fail('22023', 'already undone'); end if;
  if now() - v_original.created_at > interval '10 seconds' then perform engine.fail('22023', 'the undo window has passed'); end if;
  if v_original.kind = 'invoice_confirm' then
    perform engine.invoice_confirm_undo(p_action_id);
  end if;
  v_label := 'Undo · ' || coalesce((select ref_label from public.transactions where action_id = p_action_id limit 1), v_original.kind);
  for v_row in select * from public.transactions where action_id = p_action_id order by at loop
    perform engine.lock_product(v_row.product_id);
    if v_row.batch_id is not null then
      update public.batches set qty = qty - v_row.delta where id = v_row.batch_id;
      perform engine.ledger(v_original.clinic_id, v_row.product_id, v_row.batch_id, null, v_row.type, -v_row.delta,
        'undo', p_action_id, v_label, v_row.reason, null, v_action.o_action_id, v_row.id);
    else
      v_undated := engine.undated_batch(v_original.clinic_id, v_row.product_id);
      update public.batches set qty = qty - v_row.delta where id = v_undated;
      perform engine.ledger(v_original.clinic_id, v_row.product_id, null, null, v_row.type, -v_row.delta,
        'undo', p_action_id, v_label, v_row.reason, null, v_action.o_action_id, v_row.id);
    end if;
    perform public.refresh_product(v_row.product_id);
  end loop;
  update public.stock_actions set undone_by_action_id = v_action.o_action_id where id = p_action_id;
  return v_action.o_action_id;
end;
$$;

-- A receipt that names an invoice locks it before the clinic's lock -------------------------------------------------
-- A receipt referenced as an invoice marks the To buy lines it receives with that invoice, which Postgres checks by
-- locking the invoice row (key share) after the clinic's lock, while invoice_confirm and Undo lock that row before it.
-- The app receives through stock_receive only manually, with no invoice, but the engine takes either. MS-106's
-- stock_receive (20261016150000_stock_engine.sql), unchanged but for that invoice, locked before the clinic's lock.
create or replace function public.stock_receive(
  p_clinic_id uuid, p_lines jsonb, p_idempotency_key uuid,
  p_ref_type public.transaction_ref_type default 'manual', p_ref_id uuid default null, p_ref_label text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action record;
  v_line record;
  v_product public.products;
  v_batch uuid;
begin
  perform engine.assert_member(p_clinic_id, true);
  if p_ref_type = 'invoice' and p_ref_id is not null then
    perform 1 from public.invoices i where i.id = p_ref_id for key share;
  end if;
  v_action := engine.begin_action(p_clinic_id, p_idempotency_key, 'receive');
  if v_action.o_replay then return v_action.o_action_id; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    perform engine.fail('22023', 'nothing to receive');
  end if;
  for v_line in
    select (l->>'product_id')::uuid as product_id, (l->>'qty')::numeric as qty,
           (l->>'unit_cost')::numeric as unit_cost, nullif(l->>'lot', '') as lot, (l->>'expiry_month')::date as expiry_month
    from jsonb_array_elements(p_lines) l
  loop
    if v_line.qty is null or v_line.qty <= 0 then
      perform engine.fail('22023', 'a received quantity must be above 0');
    end if;
    v_product := engine.lock_product(v_line.product_id);
    if v_product.clinic_id <> p_clinic_id then
      perform engine.fail('42501', 'the product belongs to another clinic');
    end if;
    select id into v_batch from public.batches
    where product_id = v_product.id and expiry_month is not distinct from v_line.expiry_month and lot is not distinct from v_line.lot
    order by created_at limit 1;
    if v_batch is null then
      insert into public.batches (clinic_id, product_id, expiry_month, lot, qty)
      values (p_clinic_id, v_product.id, v_line.expiry_month, v_line.lot, v_line.qty) returning id into v_batch;
    else
      update public.batches set qty = qty + v_line.qty where id = v_batch;
    end if;
    if v_line.unit_cost is not null then
      update public.products set last_unit_cost = v_line.unit_cost where id = v_product.id;
    end if;
    perform engine.ledger(p_clinic_id, v_product.id, v_batch, null, 'receiving', v_line.qty,
      p_ref_type, p_ref_id, p_ref_label, null, null, v_action.o_action_id);
    -- A line still "to buy" counts as ordered now: the delivery is the proof.
    update public.to_buy_items set status = 'received', received_at = now(),
      ordered_at = coalesce(ordered_at, now()), ordered_by = coalesce(ordered_by, auth.uid()),
      invoice_id = case when p_ref_type = 'invoice' then p_ref_id else invoice_id end
    where product_id = v_product.id and status in ('to_buy', 'ordered');
    perform public.refresh_product(v_product.id);
  end loop;
  return v_action.o_action_id;
end;
$$;
