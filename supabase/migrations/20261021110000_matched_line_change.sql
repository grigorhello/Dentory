-- MS-130 fix (Refs #101) · A matched invoice line can be changed to another product, as decided on #101 on 2026-10-26.
-- A line read as Matched (through the supplier's own words or a near-identical name, MS-129) is no longer bound to the
-- product the reading chose: its badge opens Which product is this?, the product picked replaces the one read, and the
-- badge then reopens the line to the product it was read as. A Possible match whose suggestion is wrong is pointed at
-- another product through the same sheet (invoice_line_match took a Possible match with any product already). Each
-- line keeps the product it was read as next to the state it was read in (read_state, MS-147), and no choice changes
-- either. Confirm & receive (MS-131) learns the supplier's words for the product each line is on when it is confirmed,
-- so a line changed teaches the product chosen and points the words away from the product read; its Undo points them
-- back. MS-130's line functions are redefined from 20261021080000_invoice_review.sql (MS-131 left them as they were);
-- nothing here touches stock.

-- The product a line was read as --------------------------------------------------------------------------------------

alter table public.invoice_lines
  -- The product the reading matched a line read as Matched to; none for a line read in any other state. The line's
  -- badge reopens it to this product after the admin picked another (invoice_line_reopen).
  add column read_product_id uuid,
  add foreign key (read_product_id, clinic_id) references public.products (id, clinic_id);

-- Until now a line read as Matched could not change product, so each one is still on the product it was read as. (Set
-- before the trigger below keeps the column.)
update public.invoice_lines set read_product_id = product_id where read_state = 'matched';

-- MS-129's trigger keeps the product a line was read as beside the state it was read in: both are set from the line as
-- the reading inserts it, and no update changes them.
create or replace function engine.invoice_line_read_state()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.read_state := coalesce(new.read_state, new.state);
    new.read_product_id := case when new.read_state = 'matched' then coalesce(new.read_product_id, new.product_id) end;
  else
    new.read_state := old.read_state;
    new.read_product_id := old.read_product_id;
  end if;
  return new;
end;
$$;

-- What Review invoice shows of a line (MS-130), with the product it was read as: the screen tells a line still on that
-- product, whose badge opens Which product is this?, from one the admin changed, whose badge reopens it.
create or replace function engine.invoice_line_json(p_line_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', l.id, 'n', l.n, 'raw', l.raw, 'qty', l.qty, 'unit', l.unit, 'unit_price', l.unit_price,
    'line_total', l.line_total, 'kind', l.kind, 'state', l.state, 'read_state', l.read_state,
    'product_id', l.product_id, 'product_name', p.name, 'read_product_id', l.read_product_id,
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

-- Changing the product ------------------------------------------------------------------------------------------------

-- "Yes, match" on a Possible match, and a product picked on Which product is this? from a New product ("Pick
-- existing"), a fee ("Pick product"), a Possible match's badge or the badge of a line read as Matched: the line is
-- Matched to the product. A line read as Matched takes the product picked in place of the one it is on, whichever that
-- is; any other line is matched once, and changed after its badge reopened it.
create or replace function public.invoice_line_match(p_line_id uuid, p_product_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line public.invoice_lines := engine.invoice_line_for_review(p_line_id);
begin
  if not (v_line.read_state = 'matched' and v_line.state = 'matched') then
    perform engine.invoice_line_check_open(
      v_line, array['possible_match', 'new_product', 'needs_review']::public.invoice_line_state[]
    );
  end if;
  perform engine.invoice_line_check_product(v_line.clinic_id, p_product_id);
  update public.invoice_lines set state = 'matched', product_id = p_product_id where id = p_line_id;
  return engine.invoice_line_json(p_line_id);
end;
$$;

-- The badge of a settled line, or Undo on a Skipped one: the line goes back to the state it was read in and to the
-- product it was read as, so a line read as Matched is on that product again and any other drops the product chosen or
-- created for it (a product created stays in the clinic's products). A line already as it was read answers as it is.
create or replace function public.invoice_line_reopen(p_line_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line public.invoice_lines := engine.invoice_line_for_review(p_line_id);
begin
  if v_line.state is distinct from v_line.read_state or v_line.product_id is distinct from v_line.read_product_id then
    update public.invoice_lines set state = v_line.read_state, product_id = v_line.read_product_id where id = p_line_id;
  end if;
  return engine.invoice_line_json(p_line_id);
end;
$$;
