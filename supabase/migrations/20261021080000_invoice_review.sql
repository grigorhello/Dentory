-- MS-130 · Review invoice lines (PRD §6.5 Review invoice; Appendix B `invoice`, Appendix C `match` and `newProduct`;
-- f23, f38). The admin settles each line the reading proposed (MS-129): a Possible match is matched to its product, or
-- a product is created for it; a New product is created, or matched to a product the clinic has; a fee is ignored, or
-- matched to a product. A line the admin settled reopens in the state it was read in. Matched and Created lines carry
-- the lot and the expiry month the delivery came with. Each choice is saved as it is made, so the admin can leave the
-- screen and come back to it. Invoices and their lines now change through functions only (these, MS-129's and
-- MS-131's): an admin of the clinic, a clinic that may write (MS-142), and for the lines an invoice still waiting for
-- review. Nothing here touches stock: Confirm & receive is MS-131's.

-- What Review invoice shows of a line ----------------------------------------------------------------------------------

-- One line as the screen draws it: what was read, the state it is in and the state it was read in, the product it is
-- matched to or created as, the product a Possible match suggests, the name and unit New product starts from (for any
-- line, so "No, create new" on a Possible match is prefilled too), and the lot and expiry month.
create function engine.invoice_line_json(p_line_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', l.id, 'n', l.n, 'raw', l.raw, 'qty', l.qty, 'unit', l.unit, 'unit_price', l.unit_price,
    'line_total', l.line_total, 'kind', l.kind, 'state', l.state, 'read_state', l.read_state,
    'product_id', l.product_id, 'product_name', p.name,
    'suggested_product_id', l.suggested_product_id, 'suggested_product_name', s.name,
    'suggested_name', coalesce(l.suggested_name, engine.invoice_suggested_name(l.raw)),
    'suggested_unit', coalesce(l.suggested_unit, engine.invoice_suggested_unit(l.unit)),
    'lot', l.lot, 'expiry_month', l.expiry_month
  )
  from public.invoice_lines l
  left join public.products p on p.id = l.product_id
  left join public.products s on s.id = l.suggested_product_id
  where l.id = p_line_id;
$$;

-- Review invoice as the screen reads it: the invoice (MS-129's answer) with its lines in the order they were read.
create or replace function public.invoice_detail(p_invoice_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_clinic_id uuid;
begin
  select i.clinic_id into v_clinic_id from public.invoices i where i.id = p_invoice_id;
  if v_clinic_id is null or not coalesce(public.is_admin(v_clinic_id), false) then
    perform engine.fail('42501', 'Only an admin can receive deliveries');
  end if;
  return engine.invoice_json(p_invoice_id) || jsonb_build_object('lines', coalesce(
    (select jsonb_agg(engine.invoice_line_json(l.id) order by l.n) from public.invoice_lines l
     where l.invoice_id = p_invoice_id),
    '[]'::jsonb
  ));
end;
$$;

-- Settling a line ------------------------------------------------------------------------------------------------------

-- The line to settle, locked after its invoice (the order invoice_discard and MS-131's confirm take): an admin of its
-- clinic, a clinic that may write, and an invoice still waiting for review.
create function engine.invoice_line_for_review(p_line_id uuid)
returns public.invoice_lines
language plpgsql
set search_path = ''
as $$
declare
  v_line public.invoice_lines;
  v_status public.invoice_status;
begin
  select * into v_line from public.invoice_lines l where l.id = p_line_id;
  if v_line.id is null or not coalesce(public.is_admin(v_line.clinic_id), false) then
    perform engine.fail('42501', 'Only an admin can receive deliveries');
  end if;
  if not public.clinic_can_write(v_line.clinic_id) then
    perform engine.fail('42501', 'The clinic is read-only until a payment method is added');
  end if;
  select i.status into v_status from public.invoices i where i.id = v_line.invoice_id for update;
  if v_status is distinct from 'ready' then
    perform engine.fail('22023', 'This invoice is no longer waiting for review.');
  end if;
  select * into v_line from public.invoice_lines l where l.id = p_line_id for update;
  return v_line;
end;
$$;

-- A line that waits for the admin's choice: Possible match, New product or Needs review, as `p_states` allows.
create function engine.invoice_line_check_open(p_line public.invoice_lines, p_states public.invoice_line_state[])
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_line.state in ('matched', 'created', 'skipped') then
    perform engine.fail('22023', 'This line is already resolved.');
  end if;
  if not (p_line.state = any (p_states)) then
    perform engine.fail('22023', 'This line cannot be resolved that way.');
  end if;
end;
$$;

-- The product a line becomes: one of the clinic's products, not deleted (archived).
create function engine.invoice_line_check_product(p_clinic_id uuid, p_product_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_product public.products;
begin
  select * into v_product from public.products p where p.id = p_product_id and p.clinic_id = p_clinic_id;
  if v_product.id is null then
    perform engine.fail('22023', 'Choose a product for this line.');
  end if;
  if v_product.archived_at is not null then
    perform engine.fail('22023', 'This product was deleted.');
  end if;
end;
$$;

revoke execute on function engine.invoice_line_json(uuid), engine.invoice_line_for_review(uuid),
  engine.invoice_line_check_open(public.invoice_lines, public.invoice_line_state[]),
  engine.invoice_line_check_product(uuid, uuid)
  from public, anon, authenticated;

-- "Yes, match" on a Possible match, and a product picked on Which product is this? from a New product ("Pick
-- existing") or a fee ("Pick product"): the line is Matched to the product.
create function public.invoice_line_match(p_line_id uuid, p_product_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line public.invoice_lines := engine.invoice_line_for_review(p_line_id);
begin
  perform engine.invoice_line_check_open(v_line, array['possible_match', 'new_product', 'needs_review']::public.invoice_line_state[]);
  perform engine.invoice_line_check_product(v_line.clinic_id, p_product_id);
  update public.invoice_lines set state = 'matched', product_id = p_product_id where id = p_line_id;
  return engine.invoice_line_json(p_line_id);
end;
$$;

-- "Create and use for this line" on the New product sheet, opened from a New product ("Add new") or a Possible match
-- ("No, create new"): the line is Created as the product the sheet just created.
create function public.invoice_line_create(p_line_id uuid, p_product_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line public.invoice_lines := engine.invoice_line_for_review(p_line_id);
begin
  perform engine.invoice_line_check_open(v_line, array['possible_match', 'new_product']::public.invoice_line_state[]);
  perform engine.invoice_line_check_product(v_line.clinic_id, p_product_id);
  update public.invoice_lines set state = 'created', product_id = p_product_id where id = p_line_id;
  return engine.invoice_line_json(p_line_id);
end;
$$;

-- "Ignore" on a fee: the line is Skipped, "Ignored · not added to inventory".
create function public.invoice_line_skip(p_line_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line public.invoice_lines := engine.invoice_line_for_review(p_line_id);
begin
  perform engine.invoice_line_check_open(v_line, array['needs_review']::public.invoice_line_state[]);
  update public.invoice_lines set state = 'skipped', product_id = null where id = p_line_id;
  return engine.invoice_line_json(p_line_id);
end;
$$;

-- The badge of a settled line, or Undo on a Skipped one: the line goes back to the state it was read in. A line read
-- as Matched keeps its product; any other drops the product chosen or created for it (a product created stays in the
-- clinic's products). A line already in the state it was read in answers as it is.
create function public.invoice_line_reopen(p_line_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line public.invoice_lines := engine.invoice_line_for_review(p_line_id);
begin
  if v_line.state is distinct from v_line.read_state then
    update public.invoice_lines
    set state = v_line.read_state, product_id = case when v_line.read_state = 'matched' then product_id end
    where id = p_line_id;
  end if;
  return engine.invoice_line_json(p_line_id);
end;
$$;

-- The Lot and Expiry inputs of a Matched or Created line: free text of up to 60 characters (empty for none) and a
-- month, kept as its first day. Saved in any state, so a choice made just before the line was reopened is not lost.
create function public.invoice_line_batch(p_line_id uuid, p_lot text, p_expiry_month date)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line public.invoice_lines := engine.invoice_line_for_review(p_line_id);
  v_lot text := nullif(btrim(p_lot), '');
begin
  if length(v_lot) > 60 then
    raise exception 'Keep the lot to 60 characters.' using errcode = '22023', hint = 'lot';
  end if;
  update public.invoice_lines
  set lot = v_lot, expiry_month = date_trunc('month', p_expiry_month)::date
  where id = v_line.id;
  return engine.invoice_line_json(p_line_id);
end;
$$;

revoke execute on function public.invoice_line_match(uuid, uuid), public.invoice_line_create(uuid, uuid),
  public.invoice_line_skip(uuid), public.invoice_line_reopen(uuid), public.invoice_line_batch(uuid, text, date)
  from public, anon;
grant execute on function public.invoice_line_match(uuid, uuid), public.invoice_line_create(uuid, uuid),
  public.invoice_line_skip(uuid), public.invoice_line_reopen(uuid), public.invoice_line_batch(uuid, text, date)
  to authenticated, service_role;

-- Direct writes ----------------------------------------------------------------------------------------------------------
-- Every change of an invoice or a line has its function now, which checks what the table policies could not (the
-- state a line may move to, a product that is not deleted, an invoice still waiting for review): the direct updates
-- MS-105 opened for admins close, as MS-129 closed the inserts. Reading stays as it was.
drop policy invoices_admin_update on public.invoices;
drop policy invoice_lines_admin_update on public.invoice_lines;
revoke update on public.invoices, public.invoice_lines from authenticated;
