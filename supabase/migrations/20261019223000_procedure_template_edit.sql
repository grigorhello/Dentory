-- MS-125 · Edit procedure templates (PRD §6.3, Appendix B procEdit, f15).
-- Admins change templates through the MS-105 policies; these two functions make Save one transaction and
-- Delete procedure an archive. Both are security invoker, so the template policies still decide who may
-- write; they check the role first only to answer Staff with a sentence. Editing defaults never reaches a
-- past procedure: an event keeps its own name and supplies (`procedure_event_items`).

-- Save on Edit procedure, or New procedure when p_template_id is null. The name is trimmed, "Untitled
-- procedure" when empty, and unique among the clinic's active templates. p_items is the list in screen order,
-- [{product_id, default_qty}]: a countable product needs a default of at least 1, a multi-use product is kept
-- at 0 (it is listed under "Opened a new one?" on the start screen), and a product archived meanwhile is left
-- out. A refused name carries the hint 'name', which the app reads as the field to show it under. Answers the
-- template's id, its stored name and how many supplies it lists, for the "Procedure saved" toast.
create function public.procedure_template_save(
  p_clinic_id uuid,
  p_template_id uuid,
  p_name text,
  p_items jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text := coalesce(nullif(btrim(p_name), ''), 'Untitled procedure');
  v_items jsonb := coalesce(p_items, '[]'::jsonb);
  v_id uuid := p_template_id;
  v_taken text;
  v_item jsonb;
  v_product public.products;
  v_qty numeric;
  v_seen uuid[] := '{}';
  v_position integer := 0;
begin
  if not public.is_admin(p_clinic_id) then
    raise exception 'Only an admin can edit procedures' using errcode = '42501';
  end if;
  if not public.clinic_can_write(p_clinic_id) then
    raise exception 'The clinic is read-only until a payment method is added' using errcode = '42501';
  end if;
  if length(v_name) > 120 then
    raise exception 'Use 120 characters or fewer for the name.' using errcode = '22023', hint = 'name';
  end if;
  if jsonb_typeof(v_items) <> 'array' then
    raise exception 'Supplies must be a list' using errcode = '22023';
  end if;
  select t.name into v_taken
  from public.procedure_templates t
  where t.clinic_id = p_clinic_id and t.archived_at is null and lower(t.name) = lower(v_name)
    and t.id is distinct from p_template_id;
  if v_taken is not null then
    raise exception 'Another procedure is already called %.', v_taken using errcode = '22023', hint = 'name';
  end if;

  if v_id is null then
    insert into public.procedure_templates (clinic_id, name) values (p_clinic_id, v_name) returning id into v_id;
  else
    update public.procedure_templates t set name = v_name
    where t.id = v_id and t.clinic_id = p_clinic_id and t.archived_at is null;
    if not found then
      raise exception 'This procedure no longer exists.' using errcode = '22023';
    end if;
    delete from public.procedure_template_items i where i.template_id = v_id;
  end if;

  for v_item in select value from jsonb_array_elements(v_items) loop
    select p.* into v_product
    from public.products p
    where p.id = (v_item ->> 'product_id')::uuid and p.clinic_id = p_clinic_id;
    if v_product.id is null then
      raise exception 'A supply on the list is not a product of this clinic.' using errcode = '22023';
    end if;
    if v_product.id = any (v_seen) then
      raise exception '% is on the list twice.', v_product.name using errcode = '22023';
    end if;
    v_seen := v_seen || v_product.id;
    continue when v_product.archived_at is not null;
    if v_product.tracking = 'multi_use' then
      v_qty := 0;
    else
      v_qty := (v_item ->> 'default_qty')::numeric;
      if v_qty is null or v_qty < 1 then
        raise exception 'Set at least 1 for %.', v_product.name using errcode = '22023';
      end if;
    end if;
    v_position := v_position + 1;
    insert into public.procedure_template_items (clinic_id, template_id, product_id, default_qty, position)
    values (p_clinic_id, v_id, v_product.id, v_qty, v_position);
  end loop;

  return jsonb_build_object('id', v_id, 'name', v_name, 'item_count', v_position);
end;
$$;
revoke execute on function public.procedure_template_save(uuid, uuid, text, jsonb) from public, anon;
grant execute on function public.procedure_template_save(uuid, uuid, text, jsonb) to authenticated, service_role;

-- Delete procedure: archives the template, which leaves the Procedures list and frees its name; past
-- procedures started from it keep their data. Deleting a template that is already archived changes nothing.
create function public.procedure_template_archive(p_template_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_template public.procedure_templates;
begin
  select t.* into v_template from public.procedure_templates t where t.id = p_template_id;
  if v_template.id is null then
    raise exception 'This procedure no longer exists.' using errcode = '22023';
  end if;
  if not public.is_admin(v_template.clinic_id) then
    raise exception 'Only an admin can delete procedures' using errcode = '42501';
  end if;
  if not public.clinic_can_write(v_template.clinic_id) then
    raise exception 'The clinic is read-only until a payment method is added' using errcode = '42501';
  end if;
  if v_template.archived_at is null then
    update public.procedure_templates t set archived_at = now() where t.id = p_template_id;
  end if;
end;
$$;
revoke execute on function public.procedure_template_archive(uuid) from public, anon;
grant execute on function public.procedure_template_archive(uuid) to authenticated, service_role;
