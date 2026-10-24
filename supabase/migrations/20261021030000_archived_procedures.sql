-- MS-117 fix · Past procedures that used a deleted product can be edited and cancelled (#88, decided in the build
-- thread on 2026-10-23). Edit usage and Cancel procedure locked every product on the record through
-- engine.lock_product, which refuses an archived one, so a procedure that used a product deleted since could no longer
-- be corrected at all. Both now go through: units given back reach the deleted product's batches, a bottle opened for
-- the procedure goes back unopened, and the product stays archived. It is not refreshed, so it gets no To buy line, no
-- alert and no push. An edit may lower a deleted product's usage or take it off the record; raising it, adding it or
-- taking a new bottle of it is refused with a sentence that names it. Every other function keeps lock_product's refusal.

-- Locks the product row for the rest of the transaction and returns it, archived or not: the caller decides what a
-- deleted product may still do.
create function engine.lock_product_row(p_product_id uuid)
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
  return v_product;
end;
$$;
revoke execute on function engine.lock_product_row(uuid) from public, anon, authenticated;

-- Edit usage: MS-124's version (a multi-use row recorded at 0 stays), with a deleted product allowed to go down or off
-- the record and left unrefreshed.
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
  if v_event.cancelled_at is not null then perform engine.fail('22023', 'the procedure was cancelled'); end if;
  perform engine.assert_member(v_event.clinic_id);
  v_action := engine.begin_action(v_event.clinic_id, p_idempotency_key, 'procedure_edit');
  if v_action.o_replay then return v_action.o_action_id; end if;
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

-- Cancel procedure: MS-106's version, giving back to deleted products too and refreshing only the others.
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
  if v_event.cancelled_at is not null then perform engine.fail('22023', 'the procedure was already cancelled'); end if;
  if coalesce(length(btrim(p_note)), 0) = 0 then perform engine.fail('22023', 'a note is required to cancel'); end if;
  perform engine.assert_member(v_event.clinic_id);
  v_action := engine.begin_action(v_event.clinic_id, p_idempotency_key, 'procedure_cancel');
  if v_action.o_replay then return v_action.o_action_id; end if;

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
