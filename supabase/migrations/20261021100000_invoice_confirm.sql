-- MS-131 · Confirm and receive an invoice (PRD §6.5 Confirm, §5 To buy; Appendix B `invoice.confirm`; f23, f38;
-- MS-100 D10). Confirm & receive puts a reviewed delivery into stock in one transaction, through the engine (MS-106):
-- each Matched or Created line's quantity in counted units (5 boxes of a product received in boxes of 50 are 250
-- cartridges; a line counted in the product's own unit is not converted) on the batch of its lot and expiry month
-- (none: the undated batch, Missing expiry), at the cost per counted unit, as a receiving row in the ledger referenced
-- "Invoice {number}". The product's To buy and Ordered lines move to Received (MS-128), the supplier's words for each
-- product are learned (supplier_aliases: the next delivery matches them at once, MS-129), an empty product supplier
-- takes the invoice's, and the invoice is confirmed, which closes its delivery alert. Undo (D10: the same person,
-- within 10 seconds) puts all of it back through undo_action, and the invoice waits for review again. A received
-- invoice keeps its photo or file: discarding it was refused already (MS-129), and deleting or replacing its pages is
-- refused now too.

-- What a confirmation changed besides stock, so that its Undo puts it back -----------------------------------------------

alter table public.invoices
  -- The engine action that received the invoice (stock_actions.kind 'invoice_confirm').
  add column confirm_action_id uuid references public.stock_actions (id),
  -- The rows the confirmation changed, as they were before it: the products (last unit cost, supplier and whether a To
  -- buy suggestion of theirs was removed), their open To buy lines, and the supplier aliases it learned (product_id
  -- null) or pointed at another product (the product before).
  add column confirm_undo jsonb;

-- Counted units -----------------------------------------------------------------------------------------------------------

-- A unit as invoices and products write it, spelled one way: lower case, letters only, the usual supplier
-- abbreviations written out and a plural made singular ("BX" and "boxes" → "box", "Cartridges" → "cartridge"); the
-- words that count single items ("EA", "units", "pcs") all read "each".
create function engine.invoice_unit_word(p_unit text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when w = '' then null
    when w in ('bx', 'bxs') then 'box'
    when w in ('pk', 'pks', 'pkg', 'pkgs', 'package', 'packages') then 'pack'
    when w in ('cs', 'css') then 'case'
    when w in ('bg', 'bgs') then 'bag'
    when w in ('btl', 'btls', 'bt') then 'bottle'
    when w in ('cart', 'carts', 'ctg', 'ctgs', 'carpule', 'carpules') then 'cartridge'
    when w in ('syr', 'syrs') then 'syringe'
    when w in ('kt', 'kts') then 'kit'
    when w in ('ea', 'each', 'unit', 'units', 'pc', 'pcs', 'piece', 'pieces', 'ct', 'count') then 'each'
    when w ~ '(x|z|ch|sh|ss)es$' then left(w, -2)
    when w ~ '[^aeiou]ies$' then left(w, -3) || 'y'
    when w ~ '[^s]s$' then left(w, -1)
    else w
  end
  from (select regexp_replace(lower(coalesce(p_unit, '')), '[^a-z]', '', 'g') as w) x;
$$;

-- How many counted units one invoiced unit of a line is: the pack size for a product received in packs (PRD §4),
-- unless the line counts the product's own unit; 1 for a product without a pack. A line whose unit says neither (none
-- read, "EA", a pack word of its own) is taken to come in the packs the product is received in.
create function engine.invoice_counted_per_unit(p_line_unit text, p_unit text, p_pack_size integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when p_pack_size is null or p_pack_size <= 1 then 1
    when engine.invoice_unit_word(p_line_unit) = engine.invoice_unit_word(p_unit) then 1
    else p_pack_size
  end;
$$;

revoke execute on function engine.invoice_unit_word(text), engine.invoice_counted_per_unit(text, text, integer)
  from public, anon, authenticated;

-- What the screen reads of one invoice: MS-129's answer, with when it was received and by whom ------------------------

create or replace function engine.invoice_json(p_invoice_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', i.id, 'status', i.status, 'source', i.source, 'supplier', i.supplier, 'number', i.number,
    'invoice_date', i.invoice_date, 'total', i.total, 'currency', i.currency, 'created_at', i.created_at,
    'reading_started', i.read_started_at is not null, 'read_at', i.read_at, 'failure_reason', i.failure_reason,
    'line_count', (select count(*) from public.invoice_lines l where l.invoice_id = i.id),
    'confirmed_at', i.confirmed_at,
    'confirmed_by_name', (
      select m.full_name from public.memberships m where m.clinic_id = i.clinic_id and m.user_id = i.confirmed_by
    )
  )
  from public.invoices i
  where i.id = p_invoice_id;
$$;

-- Confirm & receive -------------------------------------------------------------------------------------------------------

-- `invoice.confirm`: an admin of the clinic, a clinic that may write (MS-142), then the key (a replay answers the first
-- action, whatever happened since), an invoice waiting for review with every line resolved, and no line on a product
-- deleted since it was settled. Answers the action id, which the toast's Undo hands to undo_action.
create function public.invoice_confirm(p_invoice_id uuid, p_idempotency_key uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invoice public.invoices;
  v_currency text;
  v_action record;
  v_line record;
  v_label text;
  v_supplier text;
  v_supplier_key text;
  v_key text;
  v_alias public.supplier_aliases;
  v_alias_id uuid;
  v_factor integer;
  v_qty numeric;
  v_cost numeric;
  v_batch uuid;
  -- The rows as they were before (see invoices.confirm_undo): products and aliases by id, the first time each is met.
  v_products jsonb := '{}';
  v_aliases jsonb := '{}';
  v_to_buy jsonb := '[]';
  v_received uuid[] := '{}';
begin
  select * into v_invoice from public.invoices i where i.id = p_invoice_id for update;
  if v_invoice.id is null or not coalesce(public.is_admin(v_invoice.clinic_id), false) then
    perform engine.fail('42501', 'Only an admin can receive deliveries');
  end if;
  if not public.clinic_can_write(v_invoice.clinic_id) then
    perform engine.fail('42501', 'The clinic is read-only until a payment method is added');
  end if;
  v_action := engine.begin_action(v_invoice.clinic_id, p_idempotency_key, 'invoice_confirm');
  if v_action.o_replay then
    return v_action.o_action_id;
  end if;
  if v_invoice.status = 'confirmed' then
    perform engine.fail('22023', 'This delivery was already received');
  end if;
  if v_invoice.status <> 'ready' then
    perform engine.fail('22023', 'This invoice is no longer waiting for review.');
  end if;
  if exists (
    select 1 from public.invoice_lines l
    where l.invoice_id = p_invoice_id and l.state not in ('matched', 'created', 'skipped')
  ) then
    perform engine.fail('22023', 'Resolve every line to continue.');
  end if;

  -- The products the lines became, locked in one order, then a line whose product was deleted since is refused.
  perform 1 from public.products p
  where p.id in (
    select l.product_id from public.invoice_lines l
    where l.invoice_id = p_invoice_id and l.state in ('matched', 'created')
  )
  order by p.id
  for update;
  select l.n, p.name into v_line
  from public.invoice_lines l
  left join public.products p on p.id = l.product_id
  where l.invoice_id = p_invoice_id and l.state in ('matched', 'created') and (p.id is null or p.archived_at is not null)
  order by l.n
  limit 1;
  if found then
    perform engine.fail('22023', case
      when v_line.name is null then format('Choose a product for line %s.', v_line.n)
      else format('%s was deleted. Choose another product for line %s.', v_line.name, v_line.n)
    end);
  end if;

  v_label := 'Invoice' || coalesce(' ' || nullif(btrim(v_invoice.number), ''), '');
  v_supplier := nullif(btrim(v_invoice.supplier), '');
  v_supplier_key := engine.invoice_alias_key(v_supplier);
  select c.currency into v_currency from public.clinics c where c.id = v_invoice.clinic_id;

  for v_line in
    select l.n, l.raw, l.qty, l.unit, l.unit_price, l.line_total, l.lot, l.expiry_month, l.product_id,
           p.unit as product_unit, p.pack_size, p.last_unit_cost, p.supplier, p.to_buy_dismissed
    from public.invoice_lines l
    join public.products p on p.id = l.product_id
    where l.invoice_id = p_invoice_id and l.state in ('matched', 'created')
    order by l.n
  loop
    if not v_products ? v_line.product_id::text then
      v_products := v_products || jsonb_build_object(v_line.product_id::text, jsonb_build_object(
        'id', v_line.product_id, 'last_unit_cost', v_line.last_unit_cost, 'supplier', v_line.supplier,
        'to_buy_dismissed', v_line.to_buy_dismissed
      ));
    end if;

    -- The supplier's words for the product, so its next delivery matches them first (MS-129).
    v_key := engine.invoice_alias_key(v_line.raw);
    if v_key <> '' then
      insert into public.supplier_aliases (clinic_id, supplier, raw_text_normalized, product_id)
      values (v_invoice.clinic_id, v_supplier_key, v_key, v_line.product_id)
      on conflict (clinic_id, supplier, raw_text_normalized) do nothing
      returning id into v_alias_id;
      if v_alias_id is not null then
        v_aliases := v_aliases || jsonb_build_object(v_alias_id::text, null);
      else
        select * into v_alias from public.supplier_aliases a
        where a.clinic_id = v_invoice.clinic_id and a.supplier = v_supplier_key and a.raw_text_normalized = v_key
        for update;
        if v_alias.product_id is distinct from v_line.product_id then
          if not v_aliases ? v_alias.id::text then
            v_aliases := v_aliases || jsonb_build_object(v_alias.id::text, v_alias.product_id);
          end if;
          update public.supplier_aliases set product_id = v_line.product_id where id = v_alias.id;
        end if;
      end if;
    end if;

    -- The supplier, set from the first invoice (PRD §4).
    if v_supplier is not null then
      update public.products set supplier = v_supplier
      where id = v_line.product_id and nullif(btrim(supplier), '') is null;
    end if;

    -- A line without a quantity above 0 goes into no stock.
    continue when coalesce(v_line.qty, 0) <= 0;
    v_factor := engine.invoice_counted_per_unit(v_line.unit, v_line.product_unit, v_line.pack_size);
    v_qty := v_line.qty * v_factor;
    if v_qty >= 1e9 then
      perform engine.fail('22023', format('The quantity on line %s is too large to receive.', v_line.n));
    end if;
    -- The price of one as invoiced, per counted unit, kept only in the clinic's own currency.
    v_cost := round(coalesce(v_line.unit_price, v_line.line_total / v_line.qty) / v_factor, 4);
    if v_invoice.currency is distinct from v_currency and v_invoice.currency is not null
       or v_cost < 0 or v_cost >= 1e8 then
      v_cost := null;
    end if;

    select b.id into v_batch from public.batches b
    where b.product_id = v_line.product_id and b.expiry_month is not distinct from v_line.expiry_month
      and b.lot is not distinct from v_line.lot
    order by b.created_at
    limit 1;
    if v_batch is null then
      insert into public.batches (clinic_id, product_id, expiry_month, lot, qty)
      values (v_invoice.clinic_id, v_line.product_id, v_line.expiry_month, v_line.lot, v_qty)
      returning id into v_batch;
    else
      update public.batches set qty = qty + v_qty where id = v_batch;
    end if;
    if v_cost is not null then
      update public.products set last_unit_cost = v_cost where id = v_line.product_id;
    end if;
    perform engine.ledger(v_invoice.clinic_id, v_line.product_id, v_batch, null, 'receiving', v_qty,
      'invoice', p_invoice_id, v_label, null, null, v_action.o_action_id);

    -- The delivery is the proof: the product's line to buy, ordered or not, is received (MS-128).
    v_to_buy := v_to_buy || coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id, 'status', t.status, 'ordered_at', t.ordered_at, 'ordered_by', t.ordered_by
      ))
      from public.to_buy_items t
      where t.product_id = v_line.product_id and t.status in ('to_buy', 'ordered')
    ), '[]');
    update public.to_buy_items
    set status = 'received', received_at = now(), ordered_at = coalesce(ordered_at, now()),
        ordered_by = coalesce(ordered_by, auth.uid()), invoice_id = p_invoice_id
    where product_id = v_line.product_id and status in ('to_buy', 'ordered');
    v_received := v_received || v_line.product_id;
  end loop;

  -- Status, alerts and To buy of each product received, once.
  perform public.refresh_product(r.id) from (select distinct unnest(v_received) as id order by 1) r;

  update public.invoices
  set status = 'confirmed', confirmed_at = now(), confirmed_by = auth.uid(), confirm_action_id = v_action.o_action_id,
      confirm_undo = jsonb_build_object(
        'products', coalesce((select jsonb_agg(p.value) from jsonb_each(v_products) p), '[]'),
        'to_buy', v_to_buy,
        'aliases', coalesce(
          (select jsonb_agg(jsonb_build_object('id', a.key, 'product_id', a.value)) from jsonb_each(v_aliases) a), '[]'
        )
      )
  where id = p_invoice_id;
  return v_action.o_action_id;
end;
$$;
revoke execute on function public.invoice_confirm(uuid, uuid) from public, anon;
grant execute on function public.invoice_confirm(uuid, uuid) to authenticated, service_role;

-- Undo ---------------------------------------------------------------------------------------------------------------------

-- What undo_action puts back besides stock when it reverses a confirmation, before the stock itself (so each product's
-- refresh finds its To buy line as it was): the To buy lines the delivery's own refresh opened for a product still low
-- go, the lines it received are to buy or ordered again (a line to buy only while none other is), each product's last
-- unit cost, supplier and removed suggestion are as before, the aliases it learned are forgotten and those it pointed
-- elsewhere point back, and the invoice waits for review again with its delivery alert open.
create function engine.invoice_confirm_undo(p_action_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_invoice public.invoices;
  v_undo jsonb;
begin
  select * into v_invoice from public.invoices i where i.confirm_action_id = p_action_id for update;
  if v_invoice.id is null or v_invoice.status <> 'confirmed' then
    return;
  end if;
  v_undo := coalesce(v_invoice.confirm_undo, '{}');
  perform 1 from public.products p
  where p.id in (select (x ->> 'id')::uuid from jsonb_array_elements(coalesce(v_undo -> 'products', '[]')) x)
  order by p.id
  for update;

  delete from public.to_buy_items t
  where t.clinic_id = v_invoice.clinic_id and t.status = 'to_buy' and t.source = 'auto'
    and t.created_at = v_invoice.confirmed_at
    and t.product_id in (select (x ->> 'id')::uuid from jsonb_array_elements(coalesce(v_undo -> 'products', '[]')) x);
  update public.to_buy_items t
  set status = x.status, ordered_at = x.ordered_at, ordered_by = x.ordered_by, received_at = null, invoice_id = null
  from jsonb_to_recordset(coalesce(v_undo -> 'to_buy', '[]'))
    as x(id uuid, status public.to_buy_status, ordered_at timestamptz, ordered_by uuid)
  where t.id = x.id and t.status = 'received' and t.invoice_id = v_invoice.id
    and (x.status <> 'to_buy' or not exists (
      select 1 from public.to_buy_items o where o.product_id = t.product_id and o.status = 'to_buy'
    ));
  update public.products p
  set last_unit_cost = x.last_unit_cost, supplier = x.supplier, to_buy_dismissed = x.to_buy_dismissed
  from jsonb_to_recordset(coalesce(v_undo -> 'products', '[]'))
    as x(id uuid, last_unit_cost numeric, supplier text, to_buy_dismissed boolean)
  where p.id = x.id;

  delete from public.supplier_aliases a
  using jsonb_to_recordset(coalesce(v_undo -> 'aliases', '[]')) as x(id uuid, product_id uuid)
  where a.id = x.id and x.product_id is null;
  update public.supplier_aliases a
  set product_id = x.product_id
  from jsonb_to_recordset(coalesce(v_undo -> 'aliases', '[]')) as x(id uuid, product_id uuid)
  where a.id = x.id and x.product_id is not null;

  update public.invoices
  set status = 'ready', confirmed_at = null, confirmed_by = null, confirm_action_id = null, confirm_undo = null
  where id = v_invoice.id;
  update public.alerts a set resolved_at = null
  where a.id = (
      select a2.id from public.alerts a2
      where a2.kind = 'invoice_ready' and a2.invoice_id = v_invoice.id
      order by a2.opened_at desc
      limit 1
    )
    and not exists (
      select 1 from public.alerts o where o.kind = 'invoice_ready' and o.invoice_id = v_invoice.id and o.resolved_at is null
    );
end;
$$;
revoke execute on function engine.invoice_confirm_undo(uuid) from public, anon, authenticated;

-- Undo: the MS-124 fix's version (20261021060000_engine_replays.sql), which also reverses a confirmed invoice; its
-- checks and their order are unchanged.
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

-- Discard invoice and Receive manually instead -------------------------------------------------------------------------

-- MS-129's invoice_discard, which the app now calls before it deletes the pages, so a delivery received meanwhile on
-- another device keeps them: it is refused, and nothing is deleted. Pages set aside before they became an invoice
-- (Receive manually instead during their upload) have no invoice to set aside: it answers null, and the pages go.
create or replace function public.invoice_discard(p_invoice_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invoice public.invoices;
begin
  select * into v_invoice from public.invoices i where i.id = p_invoice_id for update;
  if v_invoice.id is null then
    return null;
  end if;
  if not coalesce(public.is_admin(v_invoice.clinic_id), false) then
    perform engine.fail('42501', 'Only an admin can receive deliveries');
  end if;
  if not public.clinic_can_write(v_invoice.clinic_id) then
    perform engine.fail('42501', 'The clinic is read-only until a payment method is added');
  end if;
  if v_invoice.status = 'confirmed' then
    perform engine.fail('22023', 'This delivery was already received');
  end if;
  update public.invoices set status = 'discarded' where id = p_invoice_id and status <> 'discarded';
  return engine.invoice_json(p_invoice_id);
end;
$$;

-- A received invoice's pages stay (PRD §9: removing them is MS-146's own step): an admin deletes or replaces the pages
-- of any other invoice, read-only or not, as MS-129 allowed, but not those of an invoice in the folder that was
-- received.
drop policy invoices_admin_delete on storage.objects;
create policy invoices_admin_delete on storage.objects for delete to authenticated
  using (
    bucket_id = 'invoices'
    and public.is_admin((storage.foldername(name))[1]::uuid)
    and not exists (
      select 1 from public.invoices i
      where i.status = 'confirmed'
        and i.storage_path = (storage.foldername(name))[1] || '/' || (storage.foldername(name))[2]
    )
  );
drop policy invoices_admin_update on storage.objects;
create policy invoices_admin_update on storage.objects for update to authenticated
  using (
    bucket_id = 'invoices'
    and public.is_admin((storage.foldername(name))[1]::uuid)
    and not exists (
      select 1 from public.invoices i
      where i.status = 'confirmed'
        and i.storage_path = (storage.foldername(name))[1] || '/' || (storage.foldername(name))[2]
    )
  )
  with check (
    bucket_id = 'invoices'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/page-([1-9]|1[0-9]|20)\.(jpg|pdf)$'
    and public.is_admin((storage.foldername(name))[1]::uuid)
    and coalesce(public.clinic_can_write((storage.foldername(name))[1]::uuid), false)
  );
