-- MS-106 · The stock transaction engine (PRD §4 Transaction, §5 status rules, §6 flows, §9 concurrency;
-- MS-100 D9 batch order, D10 Undo). The only way stock changes: SECURITY DEFINER functions that lock the
-- product, move quantity between batches and open items, write the ledger, then refresh the product's
-- status, alerts and To buy line in the same transaction. Each call carries an idempotency key; a retry
-- returns the first result and changes nothing. A ledger delta is the change in product_stock.quantity
-- (unopened plus open for multi-use products), so opening a bottle is a 0 delta and finishing one is -1.

create schema if not exists engine;
revoke all on schema engine from public;
grant usage on schema engine to service_role;

-- Every call, for idempotency and for Undo (MS-100 D10).
create table public.stock_actions (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete restrict,
  idempotency_key uuid not null,
  kind text not null,
  by_user uuid not null references auth.users (id),
  undone_by_action_id uuid references public.stock_actions (id),
  unique (clinic_id, idempotency_key)
);
alter table public.stock_actions enable row level security;
create policy stock_actions_read on public.stock_actions for select to authenticated
  using (public.is_member(clinic_id));
grant select on public.stock_actions to authenticated;
grant select, insert, update on public.stock_actions to service_role;

-- Status (PRD §5, MS-100 D8 and G3) ----------------------------------------------------------------

-- 'out_of_stock', 'low', 'expiring', 'missing_expiry' or 'healthy', in that priority.
create function public.product_status(p_product_id uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when s.quantity <= 0 then 'out_of_stock'
    when (p.tracking = 'multi_use' and s.unopened <= p.minimum) or (p.tracking = 'countable' and s.quantity <= p.minimum) then 'low'
    when exists (
      select 1 from public.batches b
      where b.product_id = p.id and b.qty > 0 and b.expiry_month is not null
        and b.expiry_month - current_date <= (select max(t) from unnest(c.expiry_thresholds) t)
    ) then 'expiring'
    when s.missing_expiry_qty > 0 then 'missing_expiry'
    else 'healthy'
  end
  from public.products p
  join public.product_stock s on s.product_id = p.id
  join public.clinics c on c.id = p.clinic_id
  where p.id = p_product_id;
$$;
grant execute on function public.product_status(uuid) to authenticated, service_role;

-- Internals ----------------------------------------------------------------------------------------

create function engine.fail(p_code text, p_message text)
returns void
language plpgsql
as $$
begin
  raise exception '%', p_message using errcode = p_code;
end;
$$;

-- Locks the product row for the rest of the transaction and returns it.
create function engine.lock_product(p_product_id uuid)
returns public.products
language plpgsql
set search_path = ''
as $$
declare
  v_product public.products;
begin
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

create function engine.assert_member(p_clinic_id uuid, p_admin boolean default false)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_member(p_clinic_id) then
    perform engine.fail('42501', 'not a member of this clinic');
  end if;
  if p_admin and not public.is_admin(p_clinic_id) then
    perform engine.fail('42501', 'only an admin can do this');
  end if;
  if not public.clinic_can_write(p_clinic_id) then
    perform engine.fail('42501', 'the clinic is read-only until a payment method is added');
  end if;
end;
$$;

-- Registers the action; returns null when this key was already used (the caller returns the old id).
create function engine.begin_action(p_clinic_id uuid, p_key uuid, p_kind text, out o_action_id uuid, out o_replay boolean)
language plpgsql
set search_path = ''
as $$
begin
  if p_key is null then
    perform engine.fail('22023', 'an idempotency key is required');
  end if;
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

create function engine.quantity(p_product_id uuid)
returns numeric
language sql
stable
set search_path = ''
as $$
  select quantity from public.product_stock where product_id = p_product_id;
$$;

-- The one batch with no expiry and no lot, created on demand (MS-100 D9: increases and shortfalls land here).
create function engine.undated_batch(p_clinic_id uuid, p_product_id uuid)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
begin
  select id into v_id from public.batches
  where product_id = p_product_id and expiry_month is null and lot is null
  order by created_at limit 1;
  if v_id is null then
    insert into public.batches (clinic_id, product_id, qty) values (p_clinic_id, p_product_id, 0) returning id into v_id;
  end if;
  return v_id;
end;
$$;

-- Writes one ledger row after the batches changed; totals come from the view.
create function engine.ledger(
  p_clinic_id uuid, p_product_id uuid, p_batch_id uuid, p_open_item_id uuid,
  p_type public.transaction_type, p_delta numeric, p_ref_type public.transaction_ref_type, p_ref_id uuid,
  p_ref_label text, p_reason text, p_note text, p_action_id uuid, p_reverses_id uuid default null
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_after numeric := engine.quantity(p_product_id);
  v_id uuid;
begin
  insert into public.transactions (
    clinic_id, product_id, batch_id, open_item_id, type, delta, qty_before, qty_after,
    by_user, ref_type, ref_id, ref_label, reason, note, reverses_id, action_id
  ) values (
    p_clinic_id, p_product_id, p_batch_id, p_open_item_id, p_type, p_delta, v_after - p_delta, v_after,
    auth.uid(), p_ref_type, p_ref_id, p_ref_label, p_reason, p_note, p_reverses_id, p_action_id
  ) returning id into v_id;
  return v_id;
end;
$$;

-- Takes p_qty from the soonest-expiring batches first, undated last; what is left goes negative on the
-- undated batch (MS-100 D9). One ledger row per batch touched, so a cancel can give it back.
create function engine.deduct(
  p_clinic_id uuid, p_product_id uuid, p_qty numeric, p_type public.transaction_type,
  p_ref_type public.transaction_ref_type, p_ref_id uuid, p_ref_label text, p_reason text, p_note text,
  p_action_id uuid, p_open_item_id uuid default null, p_row_per_batch boolean default true
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_left numeric := p_qty;
  v_batch record;
  v_take numeric;
  v_undated uuid;
begin
  for v_batch in
    select id, qty from public.batches
    where product_id = p_product_id and qty > 0
    order by expiry_month asc nulls last, created_at
  loop
    exit when v_left <= 0;
    v_take := least(v_left, v_batch.qty);
    update public.batches set qty = qty - v_take where id = v_batch.id;
    if p_row_per_batch then
      perform engine.ledger(p_clinic_id, p_product_id, v_batch.id, p_open_item_id, p_type,
        case when p_open_item_id is null then -v_take else 0 end,
        p_ref_type, p_ref_id, p_ref_label, p_reason, p_note, p_action_id);
    end if;
    v_left := v_left - v_take;
  end loop;
  if v_left > 0 then
    v_undated := engine.undated_batch(p_clinic_id, p_product_id);
    update public.batches set qty = qty - v_left where id = v_undated;
    if p_row_per_batch then
      perform engine.ledger(p_clinic_id, p_product_id, v_undated, p_open_item_id, p_type,
        case when p_open_item_id is null then -v_left else 0 end,
        p_ref_type, p_ref_id, p_ref_label, p_reason, p_note, p_action_id);
    end if;
  end if;
  if not p_row_per_batch then
    perform engine.ledger(p_clinic_id, p_product_id, null, null, p_type, -p_qty,
      p_ref_type, p_ref_id, p_ref_label, p_reason, p_note, p_action_id);
  end if;
end;
$$;

-- Gives p_qty back to the batches an event's deductions came from, in the reverse of the order they were
-- taken (undated first, then the latest expiry); the rest goes undated.
create function engine.give_back(
  p_clinic_id uuid, p_product_id uuid, p_qty numeric, p_event_id uuid, p_type public.transaction_type,
  p_ref_label text, p_note text, p_action_id uuid
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_left numeric := p_qty;
  v_row record;
  v_give numeric;
  v_undated uuid;
begin
  for v_row in
    select t.batch_id, -sum(t.delta) as taken
    from public.transactions t
    join public.batches b on b.id = t.batch_id
    where t.product_id = p_product_id and t.ref_type = 'procedure_event' and t.ref_id = p_event_id
      and t.open_item_id is null
    group by t.batch_id, b.expiry_month
    having -sum(t.delta) > 0
    order by b.expiry_month desc nulls first
  loop
    exit when v_left <= 0;
    v_give := least(v_left, v_row.taken);
    update public.batches set qty = qty + v_give where id = v_row.batch_id;
    perform engine.ledger(p_clinic_id, p_product_id, v_row.batch_id, null, p_type, v_give,
      'procedure_event', p_event_id, p_ref_label, null, p_note, p_action_id);
    v_left := v_left - v_give;
  end loop;
  if v_left > 0 then
    v_undated := engine.undated_batch(p_clinic_id, p_product_id);
    update public.batches set qty = qty + v_left where id = v_undated;
    perform engine.ledger(p_clinic_id, p_product_id, v_undated, null, p_type, v_left,
      'procedure_event', p_event_id, p_ref_label, null, p_note, p_action_id);
  end if;
end;
$$;

-- Takes one unit out of the batches and opens it for the caller.
create function engine.open_one(
  p_clinic_id uuid, p_product_id uuid, p_event_id uuid, p_type public.transaction_type,
  p_ref_type public.transaction_ref_type, p_ref_id uuid, p_ref_label text, p_action_id uuid
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_open_item uuid;
begin
  insert into public.open_items (clinic_id, product_id, opened_by, opened_in_event_id)
  values (p_clinic_id, p_product_id, auth.uid(), p_event_id)
  returning id into v_open_item;
  perform engine.deduct(p_clinic_id, p_product_id, 1, p_type, p_ref_type, p_ref_id, p_ref_label, null, null, p_action_id, v_open_item);
  return v_open_item;
end;
$$;

-- Puts a still-open item back into its batch and closes it (a cancelled procedure, an edited take-new).
-- The row stays because the ledger points at it; it no longer counts as open.
create function engine.unopen(p_clinic_id uuid, p_open_item_id uuid, p_type public.transaction_type, p_ref_label text, p_note text, p_action_id uuid)
returns boolean
language plpgsql
set search_path = ''
as $$
declare
  v_item public.open_items;
  v_batch uuid;
begin
  select * into v_item from public.open_items where id = p_open_item_id for update;
  if not found or v_item.finished_at is not null then
    return false;
  end if;
  select batch_id into v_batch from public.transactions
  where open_item_id = p_open_item_id and batch_id is not null order by at limit 1;
  if v_batch is null then
    v_batch := engine.undated_batch(p_clinic_id, v_item.product_id);
  end if;
  delete from public.procedure_event_openings where open_item_id = p_open_item_id;
  update public.batches set qty = qty + 1 where id = v_batch;
  update public.open_items set finished_at = now(), finished_by = auth.uid() where id = p_open_item_id;
  perform engine.ledger(p_clinic_id, v_item.product_id, v_batch, p_open_item_id, p_type, 0,
    'procedure_event', v_item.opened_in_event_id, p_ref_label, null, p_note, p_action_id);
  return true;
end;
$$;

-- After every change: status, alerts and the To buy line (MS-107 and MS-128 rules).
create function public.refresh_product(p_product_id uuid)
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
  v_batch record;
  v_threshold int;
begin
  select * into v_product from public.products where id = p_product_id;
  select * into v_stock from public.product_stock where product_id = p_product_id;
  select expiry_thresholds into v_thresholds from public.clinics where id = v_product.clinic_id;
  v_status := public.product_status(p_product_id);

  -- Product-level alerts open while their condition holds and close when it clears.
  perform engine.set_alert(v_product.clinic_id, 'out_of_stock', p_product_id, null, null, v_status = 'out_of_stock');
  perform engine.set_alert(v_product.clinic_id, 'low', p_product_id, null, null, v_status = 'low');
  perform engine.set_alert(v_product.clinic_id, 'missing_expiry', p_product_id, null, null, v_stock.missing_expiry_qty > 0);

  -- One expiring alert per batch and per chosen threshold it has crossed (MS-100 D8).
  update public.alerts a set resolved_at = now()
  where a.product_id = p_product_id and a.kind = 'expiring' and a.resolved_at is null
    and not exists (
      select 1 from public.batches b
      where b.id = a.batch_id and b.qty > 0 and b.expiry_month is not null
        and b.expiry_month - current_date <= a.threshold_days
        and a.threshold_days = any (v_thresholds)
    );
  for v_batch in
    select id, expiry_month from public.batches
    where product_id = p_product_id and qty > 0 and expiry_month is not null
  loop
    foreach v_threshold in array v_thresholds loop
      if v_batch.expiry_month - current_date <= v_threshold then
        insert into public.alerts (clinic_id, kind, product_id, batch_id, threshold_days)
        values (v_product.clinic_id, 'expiring', p_product_id, v_batch.id, v_threshold)
        on conflict do nothing;
      end if;
    end loop;
  end loop;

  -- To buy: add when Low or Out of stock and nothing is pending; keep the suggestion current until ordered.
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
revoke execute on function public.refresh_product(uuid) from public, anon, authenticated;

create function engine.set_alert(p_clinic_id uuid, p_kind public.alert_kind, p_product_id uuid, p_batch_id uuid, p_threshold int, p_open boolean)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_open then
    insert into public.alerts (clinic_id, kind, product_id, batch_id, threshold_days)
    values (p_clinic_id, p_kind, p_product_id, p_batch_id, p_threshold)
    on conflict do nothing;
  else
    update public.alerts set resolved_at = now()
    where clinic_id = p_clinic_id and kind = p_kind and product_id = p_product_id
      and batch_id is not distinct from p_batch_id and threshold_days is not distinct from p_threshold
      and resolved_at is null;
  end if;
end;
$$;

-- RPC functions ------------------------------------------------------------------------------------

-- Lines: [{product_id, qty, unit_cost, lot, expiry_month}] in counted units. Admin only.
create function public.stock_receive(
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
    update public.to_buy_items set status = 'received', received_at = now(),
      invoice_id = case when p_ref_type = 'invoice' then p_ref_id else invoice_id end
    where product_id = v_product.id and status in ('to_buy', 'ordered');
    perform public.refresh_product(v_product.id);
  end loop;
  return v_action.o_action_id;
end;
$$;

-- Items: [{product_id, qty}] for countables; p_take_new lists the multi-use products to open one of.
-- The procedure event gets the action id as its own id.
create function public.stock_procedure_start(
  p_clinic_id uuid, p_template_id uuid, p_name text, p_items jsonb, p_take_new uuid[], p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action record;
  v_item record;
  v_product public.products;
  v_product_id uuid;
  v_open_item uuid;
begin
  perform engine.assert_member(p_clinic_id);
  v_action := engine.begin_action(p_clinic_id, p_idempotency_key, 'procedure_start');
  if v_action.o_replay then return v_action.o_action_id; end if;
  if coalesce(length(btrim(p_name)), 0) = 0 then
    perform engine.fail('22023', 'a procedure needs a name');
  end if;
  insert into public.procedure_events (id, clinic_id, template_id, name, started_by)
  values (v_action.o_action_id, p_clinic_id, p_template_id, p_name, auth.uid());

  for v_item in
    select (l->>'product_id')::uuid as product_id, (l->>'qty')::numeric as qty
    from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) l
  loop
    if v_item.qty is null or v_item.qty < 0 then
      perform engine.fail('22023', 'a quantity cannot be negative');
    end if;
    v_product := engine.lock_product(v_item.product_id);
    if v_product.clinic_id <> p_clinic_id then
      perform engine.fail('42501', 'the product belongs to another clinic');
    end if;
    insert into public.procedure_event_items (clinic_id, event_id, product_id, qty)
    values (p_clinic_id, v_action.o_action_id, v_product.id, v_item.qty);
    if v_item.qty > 0 then
      perform engine.deduct(p_clinic_id, v_product.id, v_item.qty, 'procedure', 'procedure_event',
        v_action.o_action_id, p_name, null, null, v_action.o_action_id);
    end if;
    perform public.refresh_product(v_product.id);
  end loop;

  foreach v_product_id in array coalesce(p_take_new, '{}') loop
    v_product := engine.lock_product(v_product_id);
    if v_product.clinic_id <> p_clinic_id or v_product.tracking <> 'multi_use' then
      perform engine.fail('22023', 'only a multi-use product of this clinic can be opened');
    end if;
    v_open_item := engine.open_one(p_clinic_id, v_product.id, v_action.o_action_id, 'procedure', 'procedure_event',
      v_action.o_action_id, p_name, v_action.o_action_id);
    insert into public.procedure_event_openings (clinic_id, event_id, product_id, open_item_id)
    values (p_clinic_id, v_action.o_action_id, v_product.id, v_open_item);
    perform public.refresh_product(v_product.id);
  end loop;
  return v_action.o_action_id;
end;
$$;

-- Writes only the differences against what the event recorded.
create function public.stock_procedure_edit(p_event_id uuid, p_items jsonb, p_take_new uuid[], p_idempotency_key uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.procedure_events;
  v_action record;
  v_label text;
  v_item record;
  v_product public.products;
  v_old numeric;
  v_delta numeric;
  v_opening record;
  v_product_id uuid;
  v_open_item uuid;
begin
  select * into v_event from public.procedure_events where id = p_event_id for update;
  if not found then perform engine.fail('22023', 'unknown procedure'); end if;
  if v_event.cancelled_at is not null then perform engine.fail('22023', 'the procedure was cancelled'); end if;
  perform engine.assert_member(v_event.clinic_id);
  v_action := engine.begin_action(v_event.clinic_id, p_idempotency_key, 'procedure_edit');
  if v_action.o_replay then return v_action.o_action_id; end if;
  v_label := 'Edited usage · ' || v_event.name;

  -- Countables: new quantity per product; a product left out of the list goes to 0.
  create temp table edit_items on commit drop as
    select (l->>'product_id')::uuid as product_id, (l->>'qty')::numeric as qty
    from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) l;
  for v_item in
    select coalesce(e.product_id, i.product_id) as product_id, coalesce(e.qty, 0) as qty
    from edit_items e
    full join (select product_id from public.procedure_event_items where event_id = p_event_id) i on i.product_id = e.product_id
  loop
    if v_item.qty < 0 then perform engine.fail('22023', 'a quantity cannot be negative'); end if;
    v_product := engine.lock_product(v_item.product_id);
    if v_product.clinic_id <> v_event.clinic_id then perform engine.fail('42501', 'the product belongs to another clinic'); end if;
    select qty into v_old from public.procedure_event_items where event_id = p_event_id and product_id = v_item.product_id;
    v_old := coalesce(v_old, 0);
    v_delta := v_item.qty - v_old;
    if v_delta > 0 then
      perform engine.deduct(v_event.clinic_id, v_product.id, v_delta, 'procedure', 'procedure_event', p_event_id, v_label, null, null, v_action.o_action_id);
    elsif v_delta < 0 then
      perform engine.give_back(v_event.clinic_id, v_product.id, -v_delta, p_event_id, 'procedure', v_label, null, v_action.o_action_id);
    end if;
    insert into public.procedure_event_items (clinic_id, event_id, product_id, qty)
    values (v_event.clinic_id, p_event_id, v_product.id, v_item.qty)
    on conflict (event_id, product_id) do update set qty = excluded.qty;
    if v_delta <> 0 then perform public.refresh_product(v_product.id); end if;
  end loop;
  delete from public.procedure_event_items where event_id = p_event_id and qty = 0;

  -- Take-new: open what is newly listed, give back what was removed and is still open.
  for v_opening in
    select o.product_id, o.open_item_id from public.procedure_event_openings o
    where o.event_id = p_event_id and not (o.product_id = any (coalesce(p_take_new, '{}')))
  loop
    perform engine.lock_product(v_opening.product_id);
    perform engine.unopen(v_event.clinic_id, v_opening.open_item_id, 'procedure', v_label, null, v_action.o_action_id);
    perform public.refresh_product(v_opening.product_id);
  end loop;
  foreach v_product_id in array coalesce(p_take_new, '{}') loop
    if not exists (select 1 from public.procedure_event_openings where event_id = p_event_id and product_id = v_product_id) then
      v_product := engine.lock_product(v_product_id);
      if v_product.clinic_id <> v_event.clinic_id or v_product.tracking <> 'multi_use' then
        perform engine.fail('22023', 'only a multi-use product of this clinic can be opened');
      end if;
      v_open_item := engine.open_one(v_event.clinic_id, v_product.id, p_event_id, 'procedure', 'procedure_event', p_event_id, v_label, v_action.o_action_id);
      insert into public.procedure_event_openings (clinic_id, event_id, product_id, open_item_id)
      values (v_event.clinic_id, p_event_id, v_product.id, v_open_item);
      perform public.refresh_product(v_product.id);
    end if;
  end loop;
  return v_action.o_action_id;
end;
$$;

-- Returns everything; a bottle that was already finished stays finished. The note is required.
create function public.stock_procedure_cancel(p_event_id uuid, p_note text, p_idempotency_key uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.procedure_events;
  v_action record;
  v_item record;
  v_opening record;
begin
  select * into v_event from public.procedure_events where id = p_event_id for update;
  if not found then perform engine.fail('22023', 'unknown procedure'); end if;
  if v_event.cancelled_at is not null then perform engine.fail('22023', 'the procedure was already cancelled'); end if;
  if coalesce(length(btrim(p_note)), 0) = 0 then perform engine.fail('22023', 'a note is required to cancel'); end if;
  perform engine.assert_member(v_event.clinic_id);
  v_action := engine.begin_action(v_event.clinic_id, p_idempotency_key, 'procedure_cancel');
  if v_action.o_replay then return v_action.o_action_id; end if;

  for v_item in select product_id, qty from public.procedure_event_items where event_id = p_event_id and qty > 0 loop
    perform engine.lock_product(v_item.product_id);
    perform engine.give_back(v_event.clinic_id, v_item.product_id, v_item.qty, p_event_id, 'cancellation', v_event.name, p_note, v_action.o_action_id);
    perform public.refresh_product(v_item.product_id);
  end loop;
  for v_opening in select product_id, open_item_id from public.procedure_event_openings where event_id = p_event_id loop
    perform engine.lock_product(v_opening.product_id);
    perform engine.unopen(v_event.clinic_id, v_opening.open_item_id, 'cancellation', v_event.name, p_note, v_action.o_action_id);
    perform public.refresh_product(v_opening.product_id);
  end loop;
  update public.procedure_events set cancelled_at = now(), cancelled_by = auth.uid(), cancel_note = p_note where id = p_event_id;
  return v_action.o_action_id;
end;
$$;

-- Counts: [{product_id, counted}], unopened only for multi-use. One count row per changed product.
create function public.stock_count_apply(p_clinic_id uuid, p_counts jsonb, p_idempotency_key uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action record;
  v_count record;
  v_product public.products;
  v_unopened numeric;
  v_delta numeric;
  v_undated uuid;
begin
  perform engine.assert_member(p_clinic_id);
  v_action := engine.begin_action(p_clinic_id, p_idempotency_key, 'count');
  if v_action.o_replay then return v_action.o_action_id; end if;
  for v_count in
    select (l->>'product_id')::uuid as product_id, (l->>'counted')::numeric as counted
    from jsonb_array_elements(coalesce(p_counts, '[]'::jsonb)) l
  loop
    if v_count.counted is null or v_count.counted < 0 then perform engine.fail('22023', 'a count cannot be negative'); end if;
    v_product := engine.lock_product(v_count.product_id);
    if v_product.clinic_id <> p_clinic_id then perform engine.fail('42501', 'the product belongs to another clinic'); end if;
    select unopened into v_unopened from public.product_stock where product_id = v_product.id;
    v_delta := v_count.counted - v_unopened;
    if v_delta < 0 then
      perform engine.deduct(p_clinic_id, v_product.id, -v_delta, 'count', 'count_session', v_action.o_action_id, 'Physical count', 'Physical count', null, v_action.o_action_id, null, false);
    elsif v_delta > 0 then
      v_undated := engine.undated_batch(p_clinic_id, v_product.id);
      update public.batches set qty = qty + v_delta where id = v_undated;
      perform engine.ledger(p_clinic_id, v_product.id, null, null, 'count', v_delta, 'count_session', v_action.o_action_id, 'Physical count', 'Physical count', null, v_action.o_action_id);
    end if;
    if v_delta <> 0 then perform public.refresh_product(v_product.id); end if;
  end loop;
  return v_action.o_action_id;
end;
$$;

-- Sets the unopened quantity with a reason (PRD §6.4 Adjust inventory).
create function public.stock_adjust(p_product_id uuid, p_actual_qty numeric, p_reason text, p_note text, p_idempotency_key uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product public.products;
  v_action record;
  v_unopened numeric;
  v_delta numeric;
  v_undated uuid;
begin
  if p_reason is null or p_reason not in ('Physical count', 'Expired', 'Damaged', 'Waste', 'Missing', 'Returned', 'Data correction', 'Other') then
    perform engine.fail('22023', 'unknown reason');
  end if;
  if p_actual_qty is null or p_actual_qty < 0 then perform engine.fail('22023', 'a quantity cannot be negative'); end if;
  v_product := engine.lock_product(p_product_id);
  perform engine.assert_member(v_product.clinic_id);
  v_action := engine.begin_action(v_product.clinic_id, p_idempotency_key, 'adjust');
  if v_action.o_replay then return v_action.o_action_id; end if;
  select unopened into v_unopened from public.product_stock where product_id = p_product_id;
  v_delta := p_actual_qty - v_unopened;
  if v_delta < 0 then
    perform engine.deduct(v_product.clinic_id, p_product_id, -v_delta, 'adjustment', 'manual', null, p_reason, p_reason, p_note, v_action.o_action_id, null, false);
  elsif v_delta > 0 then
    v_undated := engine.undated_batch(v_product.clinic_id, p_product_id);
    update public.batches set qty = qty + v_delta where id = v_undated;
    perform engine.ledger(v_product.clinic_id, p_product_id, null, null, 'adjustment', v_delta, 'manual', null, p_reason, p_reason, p_note, v_action.o_action_id);
  end if;
  perform public.refresh_product(p_product_id);
  return v_action.o_action_id;
end;
$$;

-- Removes expiring stock from one batch. Admin only.
create function public.stock_dispose(p_batch_id uuid, p_qty numeric, p_idempotency_key uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_batch public.batches;
  v_product public.products;
  v_action record;
begin
  select * into v_batch from public.batches where id = p_batch_id;
  if not found then perform engine.fail('22023', 'unknown batch'); end if;
  v_product := engine.lock_product(v_batch.product_id);
  perform engine.assert_member(v_product.clinic_id, true);
  v_action := engine.begin_action(v_product.clinic_id, p_idempotency_key, 'dispose');
  if v_action.o_replay then return v_action.o_action_id; end if;
  select * into v_batch from public.batches where id = p_batch_id for update;
  if p_qty is null or p_qty <= 0 or p_qty > v_batch.qty then
    perform engine.fail('22023', 'the disposed quantity must be between 0 and what the batch holds');
  end if;
  update public.batches set qty = qty - p_qty where id = p_batch_id;
  perform engine.ledger(v_product.clinic_id, v_product.id, p_batch_id, null, 'disposal', -p_qty, 'manual', null, 'Mark disposed', 'Expired', null, v_action.o_action_id);
  perform public.refresh_product(v_product.id);
  return v_action.o_action_id;
end;
$$;

-- Add expiry (p_batch_id null: moves undated quantity into a new dated batch) or Edit batch.
-- A quantity that is not covered by the move, or an edited quantity, is an adjustment "Data correction".
create function public.batch_upsert(p_product_id uuid, p_batch_id uuid, p_expiry_month date, p_qty numeric, p_lot text, p_idempotency_key uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product public.products;
  v_action record;
  v_batch public.batches;
  v_undated uuid;
  v_available numeric;
  v_move numeric;
  v_delta numeric;
begin
  if p_qty is null or p_qty < 0 then perform engine.fail('22023', 'a quantity cannot be negative'); end if;
  if p_expiry_month is not null and p_expiry_month <> date_trunc('month', p_expiry_month)::date then
    perform engine.fail('22023', 'the expiry is a month');
  end if;
  v_product := engine.lock_product(p_product_id);
  perform engine.assert_member(v_product.clinic_id);
  v_action := engine.begin_action(v_product.clinic_id, p_idempotency_key, 'batch_upsert');
  if v_action.o_replay then return v_action.o_action_id; end if;

  if p_batch_id is null then
    v_undated := engine.undated_batch(v_product.clinic_id, p_product_id);
    select greatest(qty, 0) into v_available from public.batches where id = v_undated;
    v_move := least(p_qty, v_available);
    update public.batches set qty = qty - v_move where id = v_undated;
    insert into public.batches (clinic_id, product_id, expiry_month, lot, qty)
    values (v_product.clinic_id, p_product_id, p_expiry_month, nullif(p_lot, ''), p_qty) returning * into v_batch;
    if p_qty > v_move then
      perform engine.ledger(v_product.clinic_id, p_product_id, v_batch.id, null, 'adjustment', p_qty - v_move, 'manual', null, 'Add expiry', 'Data correction', null, v_action.o_action_id);
    end if;
  else
    select * into v_batch from public.batches where id = p_batch_id and product_id = p_product_id for update;
    if not found then perform engine.fail('22023', 'unknown batch'); end if;
    v_delta := p_qty - v_batch.qty;
    update public.batches set expiry_month = p_expiry_month, lot = nullif(p_lot, ''), qty = p_qty where id = p_batch_id;
    if v_delta <> 0 then
      perform engine.ledger(v_product.clinic_id, p_product_id, p_batch_id, null, 'adjustment', v_delta, 'manual', null, 'Edit batch', 'Data correction', null, v_action.o_action_id);
    end if;
  end if;
  perform public.refresh_product(p_product_id);
  return v_action.o_action_id;
end;
$$;

-- Moves one unit from unopened to open for the caller (PRD §6.4 Bottles card).
create function public.bottle_open(p_product_id uuid, p_idempotency_key uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product public.products;
  v_action record;
  v_unopened numeric;
begin
  v_product := engine.lock_product(p_product_id);
  perform engine.assert_member(v_product.clinic_id);
  if v_product.tracking <> 'multi_use' then perform engine.fail('22023', 'only multi-use products are opened'); end if;
  v_action := engine.begin_action(v_product.clinic_id, p_idempotency_key, 'bottle_open');
  if v_action.o_replay then return v_action.o_action_id; end if;
  select unopened into v_unopened from public.product_stock where product_id = p_product_id;
  if v_unopened <= 0 then perform engine.fail('22023', 'Out of stock'); end if;
  perform engine.open_one(v_product.clinic_id, p_product_id, null, 'adjustment', 'manual', null, 'Opened a new bottle', v_action.o_action_id);
  perform public.refresh_product(p_product_id);
  return v_action.o_action_id;
end;
$$;

create function public.bottle_finish(p_open_item_id uuid, p_idempotency_key uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.open_items;
  v_product public.products;
  v_action record;
begin
  select * into v_item from public.open_items where id = p_open_item_id;
  if not found then perform engine.fail('22023', 'unknown open item'); end if;
  v_product := engine.lock_product(v_item.product_id);
  perform engine.assert_member(v_product.clinic_id);
  v_action := engine.begin_action(v_product.clinic_id, p_idempotency_key, 'bottle_finish');
  if v_action.o_replay then return v_action.o_action_id; end if;
  select * into v_item from public.open_items where id = p_open_item_id for update;
  if v_item.finished_at is not null then perform engine.fail('22023', 'the bottle is already finished'); end if;
  update public.open_items set finished_at = now(), finished_by = auth.uid() where id = p_open_item_id;
  perform engine.ledger(v_product.clinic_id, v_product.id, null, p_open_item_id, 'adjustment', -1, 'manual', null, 'Finished', null, null, v_action.o_action_id);
  perform public.refresh_product(v_product.id);
  return v_action.o_action_id;
end;
$$;

-- Reverses an adjustment, a receiving or a disposal: same user, within 10 seconds (MS-100 D10).
create function public.undo_action(p_action_id uuid, p_idempotency_key uuid)
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
begin
  select * into v_original from public.stock_actions where id = p_action_id for update;
  if not found then perform engine.fail('22023', 'unknown action'); end if;
  perform engine.assert_member(v_original.clinic_id);
  if v_original.by_user <> auth.uid() then perform engine.fail('42501', 'only the person who did it can undo it'); end if;
  if v_original.kind not in ('adjust', 'receive', 'dispose') then perform engine.fail('22023', 'this action cannot be undone'); end if;
  if v_original.undone_by_action_id is not null then perform engine.fail('22023', 'already undone'); end if;
  if now() - v_original.created_at > interval '10 seconds' then perform engine.fail('22023', 'the undo window has passed'); end if;
  v_action := engine.begin_action(v_original.clinic_id, p_idempotency_key, 'undo');
  if v_action.o_replay then return v_action.o_action_id; end if;
  v_label := 'Undo · ' || coalesce((select ref_label from public.transactions where action_id = p_action_id limit 1), v_original.kind);
  for v_row in select * from public.transactions where action_id = p_action_id order by at loop
    perform engine.lock_product(v_row.product_id);
    if v_row.batch_id is not null then
      update public.batches set qty = qty - v_row.delta where id = v_row.batch_id;
      perform engine.ledger(v_original.clinic_id, v_row.product_id, v_row.batch_id, null, v_row.type, -v_row.delta,
        'undo', p_action_id, v_label, v_row.reason, null, v_action.o_action_id, v_row.id);
    elsif v_row.delta > 0 then
      -- The original added to the undated batch; take it back the FEFO way (MS-100 D9).
      perform engine.deduct(v_original.clinic_id, v_row.product_id, v_row.delta, v_row.type, 'undo', p_action_id, v_label, v_row.reason, null, v_action.o_action_id, null, false);
      update public.transactions set reverses_id = v_row.id where action_id = v_action.o_action_id and product_id = v_row.product_id and reverses_id is null;
    else
      update public.batches set qty = qty - v_row.delta where id = engine.undated_batch(v_original.clinic_id, v_row.product_id);
      perform engine.ledger(v_original.clinic_id, v_row.product_id, null, null, v_row.type, -v_row.delta,
        'undo', p_action_id, v_label, v_row.reason, null, v_action.o_action_id, v_row.id);
    end if;
    perform public.refresh_product(v_row.product_id);
  end loop;
  update public.stock_actions set undone_by_action_id = v_action.o_action_id where id = p_action_id;
  return v_action.o_action_id;
end;
$$;

-- Exposure ----------------------------------------------------------------------------------------

revoke execute on function
  public.stock_receive(uuid, jsonb, uuid, public.transaction_ref_type, uuid, text),
  public.stock_procedure_start(uuid, uuid, text, jsonb, uuid[], uuid),
  public.stock_procedure_edit(uuid, jsonb, uuid[], uuid),
  public.stock_procedure_cancel(uuid, text, uuid),
  public.stock_count_apply(uuid, jsonb, uuid),
  public.stock_adjust(uuid, numeric, text, text, uuid),
  public.stock_dispose(uuid, numeric, uuid),
  public.batch_upsert(uuid, uuid, date, numeric, text, uuid),
  public.bottle_open(uuid, uuid),
  public.bottle_finish(uuid, uuid),
  public.undo_action(uuid, uuid)
from public, anon;
grant execute on function
  public.stock_receive(uuid, jsonb, uuid, public.transaction_ref_type, uuid, text),
  public.stock_procedure_start(uuid, uuid, text, jsonb, uuid[], uuid),
  public.stock_procedure_edit(uuid, jsonb, uuid[], uuid),
  public.stock_procedure_cancel(uuid, text, uuid),
  public.stock_count_apply(uuid, jsonb, uuid),
  public.stock_adjust(uuid, numeric, text, text, uuid),
  public.stock_dispose(uuid, numeric, uuid),
  public.batch_upsert(uuid, uuid, date, numeric, text, uuid),
  public.bottle_open(uuid, uuid),
  public.bottle_finish(uuid, uuid),
  public.undo_action(uuid, uuid)
to authenticated, service_role;
