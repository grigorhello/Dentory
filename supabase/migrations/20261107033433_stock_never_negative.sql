-- Fix (Refs #77, #94) · Stock never goes below 0. Grigor, 2026-11-07: "quantity can never be negative. right now number
-- of available pens is -1". MS-100 D9 and PRD §6.3 let a deduction larger than the stock go negative on the undated batch
-- ("Stock may go negative; it is shown as Out of stock, never blocked"), so a procedure that used a pen Dentory had none
-- of left the pens at -1. From now on no batch holds less than 0, and so no product does:
-- - A deduction takes what the batches hold, soonest expiry first, and stops at 0. Start procedure and Edit usage are still
--   never blocked: a short item reads 0, Out of stock, and goes on To buy. The procedure keeps the quantity it used; the
--   ledger records what left stock.
-- - Edit usage down and Cancel procedure give back what the procedure took and no more. A short item took less than it
--   used, and the part that was never in stock is the first to go when its usage goes down. Before, a give-back larger
--   than what was taken put the rest on the undated batch, which would now make stock out of nothing.
-- - Take new opens a bottle only when a whole one is left unopened. The app turns it down itself at 0 ("Out of stock",
--   PRD §6.3), so only a colleague who took the last bottle a moment before, or a start queued offline, gets here: the
--   procedure is still recorded, without that bottle, since a refused queued start would be lost. Open a new bottle
--   refused it already; no other path opens one.
-- - Undo of a delivery or an adjustment whose stock was used since is refused with a sentence instead of taking a batch
--   below 0, as Undo of an invoice already was for its dated batches (MS-131).
-- - The table holds the rule itself: batches_qty_not_negative (every batch at 0 or more) replaces
--   batches_negative_only_undated, so any later path that tries is refused by Postgres.
-- Stock already below 0 is repaired once, at the end, before the check goes on (engine.repair_negative_stock).

-- Deductions stop at 0 ----------------------------------------------------------------------------------------------------

-- Takes up to p_qty from the batches with stock, soonest expiry first, undated last, and stops when they are empty: what is
-- left was used without being in stock and moves nothing. One ledger row per batch touched, so a cancel can give it back;
-- a count or an adjustment (p_row_per_batch false) writes one row for what was taken. MS-106's function, unchanged but
-- for the end, which put the rest on the undated batch below 0.
create or replace function engine.deduct(
  p_clinic_id uuid, p_product_id uuid, p_qty numeric, p_type public.transaction_type,
  p_ref_type public.transaction_ref_type, p_ref_id uuid, p_ref_label text, p_reason text, p_note text,
  p_action_id uuid, p_open_item_id uuid default null, p_row_per_batch boolean default true,
  p_reverses_id uuid default null
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_left numeric := p_qty;
  v_batch record;
  v_take numeric;
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
  if not p_row_per_batch and v_left < p_qty then
    perform engine.ledger(p_clinic_id, p_product_id, null, null, p_type, -(p_qty - v_left),
      p_ref_type, p_ref_id, p_ref_label, p_reason, p_note, p_action_id, p_reverses_id);
  end if;
end;
$$;

-- What a procedure's supplies took of a product and still hold: its deductions less what it gave back. Bottles opened
-- for it are not supplies (unopen puts those back).
create function engine.procedure_taken(p_event_id uuid, p_product_id uuid)
returns numeric
language sql
stable
set search_path = ''
as $$
  select coalesce(-sum(t.delta), 0)
  from public.transactions t
  where t.product_id = p_product_id and t.ref_type = 'procedure_event' and t.ref_id = p_event_id
    and t.open_item_id is null and t.batch_id is not null;
$$;
revoke execute on function engine.procedure_taken(uuid, uuid) from public, anon, authenticated;

-- Gives back up to p_qty of what an event's supplies took, to the batches they came from, in the reverse of the order
-- they were taken (undated first, then the latest expiry), and never more than the event took. MS-106's function,
-- unchanged but for the end, which put a rest beyond what was taken on the undated batch.
create or replace function engine.give_back(
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
end;
$$;

-- Whether a whole unit is left unopened, so one can be opened.
create function engine.can_open(p_product_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(sum(b.qty), 0) >= 1 from public.batches b where b.product_id = p_product_id;
$$;
revoke execute on function engine.can_open(uuid) from public, anon, authenticated;

-- Takes one unit out of the batches and opens it for the caller, when a whole one is left unopened. MS-106's function,
-- unchanged but for that check: Take new used to open a bottle out of no stock and leave -1 unopened. Start procedure
-- and Edit usage ask engine.can_open first and leave the bottle out; this refusal is for any other caller.
create or replace function engine.open_one(
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
  if not engine.can_open(p_product_id) then
    perform engine.fail('22023', (select p.name from public.products p where p.id = p_product_id) || ' is out of stock.');
  end if;
  insert into public.open_items (clinic_id, product_id, opened_by, opened_in_event_id)
  values (p_clinic_id, p_product_id, auth.uid(), p_event_id)
  returning id into v_open_item;
  perform engine.deduct(p_clinic_id, p_product_id, 1, p_type, p_ref_type, p_ref_id, p_ref_label, null, null, p_action_id, v_open_item);
  return v_open_item;
end;
$$;

-- Start procedure opens only a bottle that is there ----------------------------------------------------------------------

-- MS-106's version (20261016150000_stock_engine.sql), unchanged but for Take new: a bottle is opened only when one is left
-- unopened (engine.can_open). Its supplies were never blocked and still are not; engine.deduct stops them at 0.
create or replace function public.stock_procedure_start(
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
    if engine.can_open(v_product.id) then
      v_open_item := engine.open_one(p_clinic_id, v_product.id, v_action.o_action_id, 'procedure', 'procedure_event',
        v_action.o_action_id, p_name, v_action.o_action_id);
      insert into public.procedure_event_openings (clinic_id, event_id, product_id, open_item_id)
      values (p_clinic_id, v_action.o_action_id, v_product.id, v_open_item);
      perform public.refresh_product(v_product.id);
    end if;
  end loop;
  return v_action.o_action_id;
end;
$$;

-- Edit usage gives back what was taken -----------------------------------------------------------------------------------

-- The MS-124 fix's version (20261021060000_engine_replays.sql), unchanged but for two things. A usage lowered gives back
-- what the procedure took beyond the new usage, where before the whole difference went back: both are the same for a
-- supply that was in stock, but a short one took less than it used, so lowering its usage may give nothing back. And a
-- bottle taken new is opened only when one is left (engine.can_open).
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
      perform engine.give_back(v_event.clinic_id, v_product.id,
        greatest(engine.procedure_taken(p_event_id, v_product.id) - v_item.qty, 0),
        p_event_id, 'procedure', v_label, null, v_action.o_action_id);
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
      if engine.can_open(v_product.id) then
        v_open_item := engine.open_one(v_event.clinic_id, v_product.id, p_event_id, 'procedure', 'procedure_event', p_event_id, v_label, v_action.o_action_id);
        insert into public.procedure_event_openings (clinic_id, event_id, product_id, open_item_id)
        values (v_event.clinic_id, p_event_id, v_product.id, v_open_item);
        perform public.refresh_product(v_product.id);
      end if;
    end if;
  end loop;
  return v_action.o_action_id;
end;
$$;

-- Undo refuses to take back what was used ---------------------------------------------------------------------------------

-- MS-150's version (20261021150000_performance.sql), unchanged but for one check after the window: when taking the action's
-- stock back would leave a batch below 0, because some of it was used within the 10 seconds, Undo refuses as a whole
-- (MS-100 D10 reverses an action or nothing). A reversal of a row without a batch (an adjustment) goes through the undated
-- batch, so that one is checked for it. The clinic's lock, taken by begin_action, holds the batches still until the end.
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
  if exists (
    select 1
    from (
      select coalesce(t.batch_id, u.id) as batch_id, sum(t.delta) as back
      from public.transactions t
      left join lateral (
        select b.id from public.batches b
        where b.product_id = t.product_id and b.expiry_month is null and b.lot is null
        order by b.created_at
        limit 1
      ) u on t.batch_id is null
      where t.action_id = p_action_id
      group by t.product_id, coalesce(t.batch_id, u.id)
    ) x
    left join public.batches b on b.id = x.batch_id
    where x.back > 0 and coalesce(b.qty, 0) < x.back
  ) then
    if v_original.kind in ('receive', 'invoice_confirm') then
      perform engine.fail('22023', 'Some of this delivery was used already, so it stays received.');
    end if;
    perform engine.fail('22023', 'Some of it was used already, so the adjustment stays.');
  end if;
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

-- Stock already below 0 ---------------------------------------------------------------------------------------------------

-- One correction in the ledger: the batch goes up by p_qty, as an adjustment "Data correction" named after p_by, under an
-- action of its own (kind 'repair', which Undo refuses). p_ref_type 'procedure_event' charges it to that procedure.
create function engine.repair_correction(
  p_clinic_id uuid, p_product_id uuid, p_batch_id uuid, p_qty numeric,
  p_ref_type public.transaction_ref_type, p_ref_id uuid, p_by uuid
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_action uuid;
  v_after numeric;
begin
  insert into public.stock_actions (clinic_id, idempotency_key, kind, by_user)
  values (p_clinic_id, gen_random_uuid(), 'repair', p_by)
  returning id into v_action;
  update public.batches set qty = qty + p_qty where id = p_batch_id;
  v_after := engine.quantity(p_product_id);
  insert into public.transactions (
    clinic_id, product_id, batch_id, type, delta, qty_before, qty_after, by_user, ref_type, ref_id, ref_label, reason,
    action_id
  ) values (
    p_clinic_id, p_product_id, p_batch_id, 'adjustment', p_qty, v_after - p_qty, v_after, p_by, p_ref_type, p_ref_id,
    'Stock below 0 set to 0', 'Data correction', v_action
  );
end;
$$;
revoke execute on function engine.repair_correction(uuid, uuid, uuid, numeric, public.transaction_ref_type, uuid, uuid)
  from public, anon, authenticated;

-- Brings every batch below 0 up to 0, once, before the check below goes on; returns how many it repaired.
-- 1. The product's other batches with stock cover it first, soonest expiry first: a move between batches, which leaves
--    the product's quantity as it was and so writes no ledger row (Add expiry's move writes none either). A product that
--    received a dated delivery after its shortfall keeps reading the delivery less what was used.
-- 2. What no batch covers was used without being in stock: the batch goes to 0, and so does the product, with a
--    correction in the ledger. It is charged to the procedures that took the batch below 0, latest first, up to what
--    each took from it, so cancelling or editing one of them later gives back only what it really took from stock
--    (engine.procedure_taken and engine.give_back read every row that references the procedure); each such part is
--    named after the person who last changed that procedure's usage. A part no procedure took (an Undo, or a bottle
--    opened from no stock) is a plain correction, named after whoever changed the batch last, or the clinic's first
--    admin.
-- Then each product's status, alerts and To buy line follow. Nothing calls it after this migration, since no batch can go
-- below 0 any more; it stays for its pgTAP test.
create function engine.repair_negative_stock()
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_batch record;
  v_short numeric;
  v_from record;
  v_move numeric;
  v_part record;
  v_amount numeric;
  v_by uuid;
  v_products uuid[] := '{}';
  v_count integer := 0;
begin
  for v_batch in
    select b.id, b.clinic_id, b.product_id, b.qty from public.batches b
    where b.qty < 0
    order by b.clinic_id, b.product_id, b.created_at
  loop
    v_short := -v_batch.qty;
    for v_from in
      select x.id, x.qty from public.batches x
      where x.product_id = v_batch.product_id and x.qty > 0
      order by x.expiry_month asc nulls last, x.created_at
    loop
      exit when v_short <= 0;
      v_move := least(v_short, v_from.qty);
      update public.batches set qty = qty - v_move where id = v_from.id;
      update public.batches set qty = qty + v_move where id = v_batch.id;
      v_short := v_short - v_move;
    end loop;

    if v_short > 0 then
      for v_part in
        select t.ref_id as event_id, -sum(t.delta) as taken, (array_agg(t.by_user order by t.at desc, t.id))[1] as by_user
        from public.transactions t
        where t.batch_id = v_batch.id and t.ref_type = 'procedure_event' and t.open_item_id is null
        group by t.ref_id
        having -sum(t.delta) > 0
        order by max(t.at) desc, t.ref_id
      loop
        exit when v_short <= 0;
        v_amount := least(v_short, v_part.taken);
        perform engine.repair_correction(v_batch.clinic_id, v_batch.product_id, v_batch.id, v_amount,
          'procedure_event', v_part.event_id, v_part.by_user);
        v_short := v_short - v_amount;
      end loop;
      if v_short > 0 then
        v_by := coalesce(
          (select t.by_user from public.transactions t where t.batch_id = v_batch.id order by t.at desc, t.id limit 1),
          (select m.user_id from public.memberships m
           where m.clinic_id = v_batch.clinic_id and m.role = 'admin' and m.status = 'active'
           order by m.created_at, m.id limit 1)
        );
        perform engine.repair_correction(v_batch.clinic_id, v_batch.product_id, v_batch.id, v_short, 'manual', null, v_by);
      end if;
    end if;
    v_products := v_products || v_batch.product_id;
    v_count := v_count + 1;
  end loop;

  perform public.refresh_product(p.id)
  from public.products p
  where p.id = any (v_products) and p.archived_at is null
  order by p.id;
  return v_count;
end;
$$;
revoke execute on function engine.repair_negative_stock() from public, anon, authenticated;

-- One statement, so one transaction: every clinic's stock changes wait while the repair runs (each takes its clinic's
-- lock first, MS-150, so this takes them in the same order), and the table stays held until the check is on, so nothing
-- goes below 0 in between. A LOCK TABLE of its own would be refused outside a transaction block.
do $$
begin
  perform engine.stock_lock(c.id) from public.clinics c order by c.id;
  lock table public.batches in access exclusive mode;
  perform engine.repair_negative_stock();
  alter table public.batches drop constraint batches_negative_only_undated;
  alter table public.batches add constraint batches_qty_not_negative check (qty >= 0);
end;
$$;
