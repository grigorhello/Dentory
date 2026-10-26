-- MS-124 fix (Refs #95) · A repeated Cancel procedure returns its first result. MS-106 promised that a retry with the
-- same idempotency key returns the first result and changes nothing, but stock_procedure_cancel asked whether the
-- procedure was already cancelled before engine.begin_action looked the key up, so the retry of a cancel that went
-- through found its own cancellation and was refused: a cancel whose answer was lost replayed from the app's write
-- queue into "Couldn't save. Try again." The app sends every stock function through that queue (WriteCoordinator),
-- and seven others asked, before the lookup, about a state that their own first call or someone since can change:
-- - undo_action: "already undone", which its first call sets, and the 10-second window, which a later retry misses;
-- - stock_procedure_edit: "the procedure was cancelled", once a colleague cancelled it;
-- - stock_adjust, stock_dispose, batch_upsert, bottle_open and bottle_finish: "the product is archived", raised by
--   engine.lock_product, once an admin deleted the product; and bottle_open's "only multi-use products are opened",
--   once an admin turned the product countable.
-- Each function below is its latest version with only those checks moved after the lookup; the product ones lock
-- through engine.lock_product_row (MS-117 fix), which returns an archived product too, and refuse it after the lookup
-- with lock_product's sentence. A first call is refused as before, with the same sentence, and leaves no action
-- behind. Ahead of the lookup stay the row lookups and the input checks, which a retry passes as its first call did,
-- and the permission checks: engine.assert_member's membership, admin and read-only refusals and undo's owner, so a
-- member removed, an admin made staff or a clinic turned read-only since is still refused on a retry, and nobody
-- outside the clinic learns an action id. stock_receive, stock_procedure_start and stock_count_apply looked the key up
-- first already, and bottle_finish's "already finished" and stock_dispose's quantity already followed it. Found on the
-- way and fixed in undo_action below: undoing a decrease on a product without undated stock gave nothing back.

-- Cancel procedure: the MS-117 fix's version, with "already cancelled" after the lookup.
create or replace function public.stock_procedure_cancel(p_event_id uuid, p_note text, p_idempotency_key uuid)
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
  v_product public.products;
begin
  select * into v_event from public.procedure_events where id = p_event_id for update;
  if not found then perform engine.fail('22023', 'unknown procedure'); end if;
  if coalesce(length(btrim(p_note)), 0) = 0 then perform engine.fail('22023', 'a note is required to cancel'); end if;
  perform engine.assert_member(v_event.clinic_id);
  v_action := engine.begin_action(v_event.clinic_id, p_idempotency_key, 'procedure_cancel');
  if v_action.o_replay then return v_action.o_action_id; end if;
  if v_event.cancelled_at is not null then perform engine.fail('22023', 'the procedure was already cancelled'); end if;

  for v_item in select product_id, qty from public.procedure_event_items where event_id = p_event_id and qty > 0 loop
    v_product := engine.lock_product_row(v_item.product_id);
    perform engine.give_back(v_event.clinic_id, v_item.product_id, v_item.qty, p_event_id, 'cancellation', v_event.name, p_note, v_action.o_action_id);
    if v_product.archived_at is null then perform public.refresh_product(v_product.id); end if;
  end loop;
  for v_opening in select product_id, open_item_id from public.procedure_event_openings where event_id = p_event_id loop
    v_product := engine.lock_product_row(v_opening.product_id);
    perform engine.unopen(v_event.clinic_id, v_opening.open_item_id, 'cancellation', v_event.name, p_note, v_action.o_action_id);
    if v_product.archived_at is null then perform public.refresh_product(v_product.id); end if;
  end loop;
  update public.procedure_events set cancelled_at = now(), cancelled_by = auth.uid(), cancel_note = p_note where id = p_event_id;
  return v_action.o_action_id;
end;
$$;

-- Edit usage: the MS-117 fix's version, with "the procedure was cancelled" after the lookup.
create or replace function public.stock_procedure_edit(p_event_id uuid, p_items jsonb, p_take_new uuid[], p_idempotency_key uuid)
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
  v_listed uuid[];
begin
  select * into v_event from public.procedure_events where id = p_event_id for update;
  if not found then perform engine.fail('22023', 'unknown procedure'); end if;
  perform engine.assert_member(v_event.clinic_id);
  v_action := engine.begin_action(v_event.clinic_id, p_idempotency_key, 'procedure_edit');
  if v_action.o_replay then return v_action.o_action_id; end if;
  if v_event.cancelled_at is not null then perform engine.fail('22023', 'the procedure was cancelled'); end if;
  v_label := 'Edited usage · ' || v_event.name;
  select coalesce(array_agg((l->>'product_id')::uuid), '{}') into v_listed
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) l;

  -- Countables: new quantity per product; a product left out of the list goes to 0.
  for v_item in
    with edit_items as (
      select (l->>'product_id')::uuid as product_id, (l->>'qty')::numeric as qty
      from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) l
    )
    select coalesce(e.product_id, i.product_id) as product_id, coalesce(e.qty, 0) as qty
    from edit_items e
    full join (select product_id from public.procedure_event_items where event_id = p_event_id) i on i.product_id = e.product_id
  loop
    if v_item.qty < 0 then perform engine.fail('22023', 'a quantity cannot be negative'); end if;
    v_product := engine.lock_product_row(v_item.product_id);
    if v_product.clinic_id <> v_event.clinic_id then perform engine.fail('42501', 'the product belongs to another clinic'); end if;
    select qty into v_old from public.procedure_event_items where event_id = p_event_id and product_id = v_item.product_id;
    -- A deleted product goes down or stays; one the procedure never recorded (as a supply or a bottle) is not added.
    if v_product.archived_at is not null and (
      v_item.qty > coalesce(v_old, 0)
      or (v_old is null and not exists (
        select 1 from public.procedure_event_openings o where o.event_id = p_event_id and o.product_id = v_product.id
      ))
    ) then
      perform engine.fail('22023', v_product.name || ' was deleted. Its usage can go down, not up.');
    end if;
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
    if v_delta <> 0 and v_product.archived_at is null then perform public.refresh_product(v_product.id); end if;
  end loop;
  delete from public.procedure_event_items i
  using public.products p
  where i.event_id = p_event_id and p.id = i.product_id
    and (not (i.product_id = any (v_listed)) or (i.qty = 0 and p.tracking = 'countable'));

  -- Take-new: open what is newly listed, give back what was removed and is still open.
  for v_opening in
    select o.product_id, o.open_item_id from public.procedure_event_openings o
    where o.event_id = p_event_id and not (o.product_id = any (coalesce(p_take_new, '{}')))
  loop
    v_product := engine.lock_product_row(v_opening.product_id);
    perform engine.unopen(v_event.clinic_id, v_opening.open_item_id, 'procedure', v_label, null, v_action.o_action_id);
    if v_product.archived_at is null then perform public.refresh_product(v_product.id); end if;
  end loop;
  foreach v_product_id in array coalesce(p_take_new, '{}') loop
    if not exists (select 1 from public.procedure_event_openings where event_id = p_event_id and product_id = v_product_id) then
      v_product := engine.lock_product_row(v_product_id);
      if v_product.clinic_id <> v_event.clinic_id or v_product.tracking <> 'multi_use' then
        perform engine.fail('22023', 'only a multi-use product of this clinic can be opened');
      end if;
      if v_product.archived_at is not null then
        perform engine.fail('22023', v_product.name || ' was deleted. No new bottle can be opened for it.');
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

-- Undo: MS-106's version, with "already undone" and the 10-second window after the lookup, so a retry of an undo
-- made in time returns it; the owner check stays ahead of it. Also fixed: undoing a decrease of a product that had no
-- undated batch wrote the reversal to the ledger but gave nothing back, because the update looked the undated batch up
-- in its own where clause, and a batch created there is one that update cannot see.
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
  if v_original.kind not in ('adjust', 'receive', 'dispose') then perform engine.fail('22023', 'this action cannot be undone'); end if;
  v_action := engine.begin_action(v_original.clinic_id, p_idempotency_key, 'undo');
  if v_action.o_replay then return v_action.o_action_id; end if;
  if v_original.undone_by_action_id is not null then perform engine.fail('22023', 'already undone'); end if;
  if now() - v_original.created_at > interval '10 seconds' then perform engine.fail('22023', 'the undo window has passed'); end if;
  v_label := 'Undo · ' || coalesce((select ref_label from public.transactions where action_id = p_action_id limit 1), v_original.kind);
  for v_row in select * from public.transactions where action_id = p_action_id order by at loop
    perform engine.lock_product(v_row.product_id);
    if v_row.batch_id is not null then
      update public.batches set qty = qty - v_row.delta where id = v_row.batch_id;
      perform engine.ledger(v_original.clinic_id, v_row.product_id, v_row.batch_id, null, v_row.type, -v_row.delta,
        'undo', p_action_id, v_label, v_row.reason, null, v_action.o_action_id, v_row.id);
    else
      -- A count or adjustment row carries no batch; its reversal goes through the undated batch (MS-100 D9), found or
      -- created before the update, whose scan would not see a batch created while it runs.
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

-- Adjust: MS-106's version, refusing a deleted product after the lookup.
create or replace function public.stock_adjust(p_product_id uuid, p_actual_qty numeric, p_reason text, p_note text, p_idempotency_key uuid)
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
  v_product := engine.lock_product_row(p_product_id);
  perform engine.assert_member(v_product.clinic_id);
  v_action := engine.begin_action(v_product.clinic_id, p_idempotency_key, 'adjust');
  if v_action.o_replay then return v_action.o_action_id; end if;
  if v_product.archived_at is not null then perform engine.fail('22023', 'the product is archived'); end if;
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

-- Mark disposed: MS-106's version, refusing a deleted product after the lookup.
create or replace function public.stock_dispose(p_batch_id uuid, p_qty numeric, p_idempotency_key uuid)
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
  v_product := engine.lock_product_row(v_batch.product_id);
  perform engine.assert_member(v_product.clinic_id, true);
  v_action := engine.begin_action(v_product.clinic_id, p_idempotency_key, 'dispose');
  if v_action.o_replay then return v_action.o_action_id; end if;
  if v_product.archived_at is not null then perform engine.fail('22023', 'the product is archived'); end if;
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

-- Add expiry and Edit batch: MS-106's version, refusing a deleted product after the lookup.
create or replace function public.batch_upsert(p_product_id uuid, p_batch_id uuid, p_expiry_month date, p_qty numeric, p_lot text, p_idempotency_key uuid)
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
  v_product := engine.lock_product_row(p_product_id);
  perform engine.assert_member(v_product.clinic_id);
  v_action := engine.begin_action(v_product.clinic_id, p_idempotency_key, 'batch_upsert');
  if v_action.o_replay then return v_action.o_action_id; end if;
  if v_product.archived_at is not null then perform engine.fail('22023', 'the product is archived'); end if;

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

-- Open a new bottle: MS-106's version, refusing a deleted or countable product after the lookup.
create or replace function public.bottle_open(p_product_id uuid, p_idempotency_key uuid)
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
  v_product := engine.lock_product_row(p_product_id);
  perform engine.assert_member(v_product.clinic_id);
  v_action := engine.begin_action(v_product.clinic_id, p_idempotency_key, 'bottle_open');
  if v_action.o_replay then return v_action.o_action_id; end if;
  if v_product.archived_at is not null then perform engine.fail('22023', 'the product is archived'); end if;
  if v_product.tracking <> 'multi_use' then perform engine.fail('22023', 'only multi-use products are opened'); end if;
  select unopened into v_unopened from public.product_stock where product_id = p_product_id;
  if v_unopened <= 0 then perform engine.fail('22023', 'Out of stock'); end if;
  perform engine.open_one(v_product.clinic_id, p_product_id, null, 'adjustment', 'manual', null, 'Opened a new bottle', v_action.o_action_id);
  perform public.refresh_product(p_product_id);
  return v_action.o_action_id;
end;
$$;

-- Finished: MS-106's version, refusing a deleted product after the lookup.
create or replace function public.bottle_finish(p_open_item_id uuid, p_idempotency_key uuid)
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
  v_product := engine.lock_product_row(v_item.product_id);
  perform engine.assert_member(v_product.clinic_id);
  v_action := engine.begin_action(v_product.clinic_id, p_idempotency_key, 'bottle_finish');
  if v_action.o_replay then return v_action.o_action_id; end if;
  if v_product.archived_at is not null then perform engine.fail('22023', 'the product is archived'); end if;
  select * into v_item from public.open_items where id = p_open_item_id for update;
  if v_item.finished_at is not null then perform engine.fail('22023', 'the bottle is already finished'); end if;
  update public.open_items set finished_at = now(), finished_by = auth.uid() where id = p_open_item_id;
  perform engine.ledger(v_product.clinic_id, v_product.id, null, p_open_item_id, 'adjustment', -1, 'manual', null, 'Finished', null, null, v_action.o_action_id);
  perform public.refresh_product(v_product.id);
  return v_action.o_action_id;
end;
$$;
