-- MS-124 · A procedure from history: edit usage or cancel (PRD §6.3 From history, Appendix B `procDetail` in modes
-- done and editing, Appendix C `cancelProcedure`; f14). Editing and cancelling use MS-106's stock_procedure_edit
-- and stock_procedure_cancel; this migration adds the read and keeps a multi-use row recorded at 0 through an edit.

-- One procedure as the screen opens it: name, when, who, the cancellation if any, and its supplies in the
-- template's order (added ones after, by name) with what each used, whether a new bottle was opened for it, and the
-- stock it takes from today. A bottle opened for the procedure counts even when its product was not recorded as a
-- supply. Security invoker, so RLS keeps each clinic to itself; null for an event the caller cannot see.
create function public.procedure_event_detail(p_event_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'id', e.id,
    'template_id', e.template_id,
    'name', e.name,
    'started_at', e.started_at,
    'started_by_name', coalesce(starter.full_name, ''),
    'cancelled_at', e.cancelled_at,
    'cancelled_by_name', coalesce(canceller.full_name, ''),
    'cancel_note', e.cancel_note,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'name', p.name,
        'unit', p.unit,
        'tracking', p.tracking,
        'qty', coalesce(i.qty, 0),
        'taken_new', exists (
          select 1 from public.procedure_event_openings o where o.event_id = e.id and o.product_id = p.id
        ),
        'quantity', s.quantity,
        'unopened', s.unopened,
        'open_count', s.open_count
      ) order by ti.position nulls last, p.name)
      from (
        select i.product_id from public.procedure_event_items i where i.event_id = e.id
        union
        select o.product_id from public.procedure_event_openings o where o.event_id = e.id
      ) used
      join public.products p on p.id = used.product_id
      join public.product_stock s on s.product_id = p.id
      left join public.procedure_event_items i on i.event_id = e.id and i.product_id = p.id
      left join public.procedure_template_items ti on ti.template_id = e.template_id and ti.product_id = p.id
    ), '[]'::jsonb)
  )
  from public.procedure_events e
  left join public.memberships starter on starter.clinic_id = e.clinic_id and starter.user_id = e.started_by
  left join public.memberships canceller on canceller.clinic_id = e.clinic_id and canceller.user_id = e.cancelled_by
  where e.id = p_event_id;
$$;
revoke execute on function public.procedure_event_detail(uuid) from public, anon;
grant execute on function public.procedure_event_detail(uuid) to authenticated, service_role;

-- Edit usage: unchanged but for the rows it keeps. A multi-use product is recorded at 0 when its open bottle was
-- used (MS-123 sends it so), and an edit that lists it again at 0 keeps it; a product left off the list, or a
-- countable one set to 0, leaves the record. Before, every row at 0 was dropped, so an edit lost "Used from open
-- bottle".
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
  delete from public.procedure_event_items i
  using public.products p
  where i.event_id = p_event_id and p.id = i.product_id
    and (not (i.product_id = any (v_listed)) or (i.qty = 0 and p.tracking = 'countable'));

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
