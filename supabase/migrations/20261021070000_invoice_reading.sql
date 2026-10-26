-- MS-129 · Read invoices with AI (PRD §6.5 Reading state, §9 Invoice reading; f23, f38; Appendix B `invoice`).
-- The app uploads a delivery's captured pages to the private invoices bucket as {clinic_id}/{invoice_id}/page-n.jpg
-- (or the one page-1.pdf), creates the invoice with invoice_create (status reading) and asks the extract_invoice Edge
-- Function to read it. The function claims the reading (invoice_reading_start), sends the pages to the Claude API and
-- hands what it read to invoice_reading_finish, which matches each line against the clinic's products here,
-- deterministically and without AI, saves the lines and marks the invoice ready, opening the "Delivery read and waiting
-- for review" alert and with it the admins' push (MS-144). A reading that fails marks the invoice failed with a reason
-- (invoice_reading_fail), and each minute engine.invoice_reading_timeout fails a reading nobody finished in time.
-- Nothing here touches stock: batches, the ledger, open items and To buy change only when the admin confirms (MS-131).

create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

-- Invoices ---------------------------------------------------------------------------------------------------------

alter table public.invoices
  -- What was uploaded under storage_path ({clinic_id}/{invoice_id}): page-1.jpg … page-n.jpg, or one page-1.pdf.
  add column file_kind text check (file_kind in ('jpg', 'pdf')),
  add column file_count integer check (file_count between 1 and 20),
  -- When extract_invoice claimed the reading, and when the reading ended (ready or failed). created_at is when the
  -- upload finished, the start of "time from upload to confirm" (MS-147, sent by MS-131 with invoice.confirm).
  add column read_started_at timestamptz,
  add column read_at timestamptz,
  -- Why a reading failed: it ran out of time, the pages held no invoice lines, the model declined, or anything else.
  add column failure_reason text check (failure_reason in ('timeout', 'unreadable', 'refused', 'error')),
  add constraint invoices_files check (
    (file_kind is null) = (file_count is null) and (file_kind is distinct from 'pdf' or file_count = 1)
  );
create index invoices_reading_idx on public.invoices (created_at) where status = 'reading';

alter table public.invoice_lines
  -- What the reader called the line: a product, or a fee, surcharge, shipping, tax, discount or credit.
  add column kind text not null default 'product' check (kind in ('product', 'fee')),
  -- The state matching gave the line when it was read. `state` follows the admin's choices (MS-130); this one stays,
  -- so MS-131 can report how many lines were matched automatically (MS-147).
  add column read_state public.invoice_line_state,
  -- The trigram similarity of the closest product, when one was compared (PRD §9: tuning the thresholds later).
  add column match_score real check (match_score between 0 and 1),
  -- A new product's name and counted-in unit, suggested from the line for New product's sheet (MS-130).
  add column suggested_name text check (length(suggested_name) between 1 and 120),
  add column suggested_unit text check (length(suggested_unit) between 1 and 30);

create function engine.invoice_line_read_state()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.read_state := case when tg_op = 'INSERT' then coalesce(new.read_state, new.state) else old.read_state end;
  return new;
end;
$$;
revoke execute on function engine.invoice_line_read_state() from public, anon, authenticated;

update public.invoice_lines set read_state = state where read_state is null;
alter table public.invoice_lines alter column read_state set not null;
create trigger invoice_lines_read_state before insert or update on public.invoice_lines
  for each row execute function engine.invoice_line_read_state();

-- Invoices and their lines are written by the functions below only: an invoice starts with invoice_create, its lines
-- come from the reading. Admins keep reading them and updating lines as they resolve them (MS-130).
drop policy invoices_admin_insert on public.invoices;
drop policy invoice_lines_admin_insert on public.invoice_lines;
revoke insert on public.invoices, public.invoice_lines from authenticated;

-- A delivery waiting for review stops waiting once its invoice is confirmed or discarded: its alert closes (PRD §5).
create function engine.invoice_resolve_ready_alert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = 'ready' and new.status <> 'ready' then
    update public.alerts set resolved_at = now()
    where kind = 'invoice_ready' and invoice_id = new.id and resolved_at is null;
  end if;
  return null;
end;
$$;
revoke execute on function engine.invoice_resolve_ready_alert() from public, anon, authenticated;

create trigger invoices_resolve_ready_alert after update of status on public.invoices
  for each row execute function engine.invoice_resolve_ready_alert();

-- Storage ----------------------------------------------------------------------------------------------------------
-- Only the files a reading takes, named as the app names them, at most 20 MB each, written while the clinic may write
-- (the logos bucket got the same in 20261021000000_read_only_access.sql). Admins read and delete their clinic's files,
-- read-only or not: the images belong to the clinic (PRD §9).

update storage.buckets
set file_size_limit = 20000000, allowed_mime_types = array['image/jpeg', 'application/pdf']
where id = 'invoices';

drop policy invoices_admin_objects on storage.objects;
create policy invoices_admin_read on storage.objects for select to authenticated
  using (bucket_id = 'invoices' and public.is_admin((storage.foldername(name))[1]::uuid));
create policy invoices_admin_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'invoices'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/page-([1-9]|1[0-9]|20)\.(jpg|pdf)$'
    and public.is_admin((storage.foldername(name))[1]::uuid)
    and coalesce(public.clinic_can_write((storage.foldername(name))[1]::uuid), false)
  );
create policy invoices_admin_update on storage.objects for update to authenticated
  using (bucket_id = 'invoices' and public.is_admin((storage.foldername(name))[1]::uuid))
  with check (
    bucket_id = 'invoices'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/page-([1-9]|1[0-9]|20)\.(jpg|pdf)$'
    and public.is_admin((storage.foldername(name))[1]::uuid)
    and coalesce(public.clinic_can_write((storage.foldername(name))[1]::uuid), false)
  );
create policy invoices_admin_delete on storage.objects for delete to authenticated
  using (bucket_id = 'invoices' and public.is_admin((storage.foldername(name))[1]::uuid));

-- Matching (PRD §9: deterministic, no AI) ----------------------------------------------------------------------------

-- The words a supplier alias is kept under ("SEPTO 4% 1:100K 50/BX" → "septo 4 1 100k 50 bx"), and the supplier's
-- too: lower case, no accents, every run of other characters one space. MS-131 learns aliases with the same key.
create function engine.invoice_alias_key(p_text text)
returns text
language sql
stable
set search_path = ''
as $$
  select btrim(regexp_replace(
    lower(extensions.unaccent('extensions.unaccent'::regdictionary, coalesce(p_text, ''))), '[^a-z0-9]+', ' ', 'g'
  ));
$$;

-- The words a line and a product name are compared by: the alias key's words with thousands written out ("100K" and
-- "1:100,000" both 100000), the pack counts left out ("50/BX", "1PK", "2 cases"), letters and digits apart ("27G" →
-- "27 g", "A2" → "a 2"), and the pack and form words left out ("box", "cartridges", "kit"): they say how a product
-- comes rather than which product it is.
create function engine.invoice_match_text(p_text text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_text text := lower(extensions.unaccent('extensions.unaccent'::regdictionary, coalesce(p_text, '')));
  v_packs text := 'bx|box|boxes|pk|pkg|pack|packs|package|packages|cs|case|cases|bg|bag|bags|ea|each|ct|count|'
    || 'units?|pcs?|pieces?|bte|boites?';
begin
  v_text := regexp_replace(regexp_replace(v_text, '(\d),(\d{3})', '\1\2', 'g'), '(\d),(\d{3})', '\1\2', 'g');
  v_text := regexp_replace(v_text, '(\d+)k\M', '\1000', 'g');
  v_text := regexp_replace(v_text, '\m\d+\s*/\s*[a-z]+\M', ' ', 'g');
  v_text := regexp_replace(v_text, '\m\d+\s*(?:' || v_packs || ')\M', ' ', 'g');
  v_text := regexp_replace(regexp_replace(v_text, '(\d)([a-z])', '\1 \2', 'g'), '([a-z])(\d)', '\1 \2', 'g');
  v_text := regexp_replace(v_text, '[^a-z0-9]+', ' ', 'g');
  v_text := regexp_replace(' ' || v_text || ' ',
    ' (?:' || v_packs || '|cartridges?|carts?|carpules?|syringes?|syr|tubes?|bottles?|btl|bt|jars?|kits?)(?= )',
    ' ', 'g');
  return btrim(regexp_replace(v_text, '\s+', ' ', 'g'));
end;
$$;

-- The numbers in a match text, which tell variants apart: a size, strength, shade or length ("27 g", "a 2", "21 mm").
create function engine.invoice_variant_numbers(p_match_text text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(distinct w order by w), '{}')
  from regexp_split_to_table(coalesce(p_match_text, ''), ' ') w
  where w ~ '^\d+$';
$$;

-- A new product's name from its line: the pack words left out, and a line written in capitals put in sentence case,
-- keeping short words and words with digits as written ("TEMPBOND NE 1PK" → "Tempbond NE").
create function engine.invoice_suggested_name(p_raw text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text := coalesce(p_raw, '');
  v_words text[];
  v_name text := '';
begin
  v_text := regexp_replace(v_text, '\m\d+\s*/\s*[[:alpha:]]+\M', ' ', 'g');
  v_text := regexp_replace(v_text, '\m\d*\s*(?:bx|pk|pkg|cs|ea|ct)\M', ' ', 'gi');
  v_text := btrim(regexp_replace(v_text, '\s+', ' ', 'g'), ' -/,.;:');
  if v_text = '' then
    return null;
  end if;
  if v_text = upper(v_text) then
    v_words := string_to_array(v_text, ' ');
    for i in 1 .. array_length(v_words, 1) loop
      v_name := v_name || case when i > 1 then ' ' else '' end || case
        when v_words[i] ~ '\d' or (i > 1 and length(v_words[i]) <= 2) then v_words[i]
        when i = 1 then upper(left(v_words[i], 1)) || lower(substr(v_words[i], 2))
        else lower(v_words[i])
      end;
    end loop;
    v_text := v_name;
  end if;
  return left(v_text, 120);
end;
$$;

-- A new product's counted-in unit from the line's unit, in the plural the products keep ("pack" → "packs"); "units"
-- when the line has none or counts each.
create function engine.invoice_suggested_unit(p_unit text)
returns text
language sql
immutable
set search_path = ''
as $$
  select left(case
    when u is null or u in ('each', 'ea', 'unit', 'units', 'piece', 'pieces', 'pc', 'pcs') then 'units'
    when u ~ 's$' then u
    when u ~ '(x|z|ch|sh)$' then u || 'es'
    when u ~ '[^aeiou]y$' then left(u, -1) || 'ies'
    else u || 's'
  end, 30)
  from (select nullif(btrim(lower(p_unit)), '') as u) x;
$$;

-- The state one line is read in (PRD §9, in order): a fee, surcharge, shipping, tax, discount or credit line is Needs
-- review; (a) the supplier's own words for a product, learned when one of its deliveries was confirmed (MS-131), are
-- Matched; (b) the closest active product by trigram similarity is Matched from 0.75 when its numbers agree with the
-- line's (a size, strength or shade that differs is never applied automatically), and a Possible match from 0.45 or
-- when they differ; (c) anything else is a New product, its name and unit suggested from the line.
create function engine.invoice_match_line(
  p_clinic_id uuid,
  p_supplier_key text,
  p_raw text,
  p_kind text,
  p_unit text,
  p_qty numeric,
  p_line_total numeric,
  out o_state public.invoice_line_state,
  out o_product_id uuid,
  out o_suggested_product_id uuid,
  out o_score real,
  out o_suggested_name text,
  out o_suggested_unit text
)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_key text := engine.invoice_alias_key(p_raw);
  v_text text := engine.invoice_match_text(p_raw);
  v_alias uuid;
  v_best record;
begin
  if p_kind = 'fee' or coalesce(p_qty, 0) < 0 or coalesce(p_line_total, 0) < 0
     or v_key ~ ('\m(?:shipping|freight|handling|surcharges?|delivery|fuel|tax|taxes|hst|gst|pst|qst|tps|tvq|fees?|'
       || 'restocking|environmental|discounts?|rebates?|credit|frais|livraison|transport|taxe|escompte|rabais)\M') then
    o_state := 'needs_review';
    return;
  end if;

  select a.product_id into v_alias
  from public.supplier_aliases a
  join public.products p on p.id = a.product_id and p.archived_at is null
  where a.clinic_id = p_clinic_id and a.supplier = coalesce(p_supplier_key, '') and a.raw_text_normalized = v_key;
  if v_alias is null then
    -- Another supplier's words, when every alias with them names the same product (a supplier read slightly
    -- differently on another invoice).
    select min(a.product_id::text)::uuid into v_alias
    from public.supplier_aliases a
    join public.products p on p.id = a.product_id and p.archived_at is null
    where a.clinic_id = p_clinic_id and a.raw_text_normalized = v_key
    having count(distinct a.product_id) = 1;
  end if;
  if v_alias is not null then
    o_state := 'matched';
    o_product_id := v_alias;
    return;
  end if;

  select c.id, c.text, extensions.similarity(c.text, v_text) as score into v_best
  from (
    select p.id, p.name, engine.invoice_match_text(p.name) as text
    from public.products p
    where p.clinic_id = p_clinic_id and p.archived_at is null
  ) c
  order by 3 desc, lower(c.name), c.id
  limit 1;
  if v_best.id is not null and v_text <> '' then
    o_score := v_best.score;
    if v_best.score >= 0.75
       and engine.invoice_variant_numbers(v_best.text) = engine.invoice_variant_numbers(v_text) then
      o_state := 'matched';
      o_product_id := v_best.id;
      return;
    elsif v_best.score >= 0.45 then
      o_state := 'possible_match';
      o_suggested_product_id := v_best.id;
      return;
    end if;
  end if;

  o_state := 'new_product';
  o_suggested_name := engine.invoice_suggested_name(p_raw);
  o_suggested_unit := engine.invoice_suggested_unit(p_unit);
end;
$$;

-- What the screen reads of one invoice (Review invoice, reading state): its state, the header once read, why it
-- failed, and how many lines it has.
create function engine.invoice_json(p_invoice_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', i.id, 'status', i.status, 'source', i.source, 'supplier', i.supplier, 'number', i.number,
    'invoice_date', i.invoice_date, 'total', i.total, 'currency', i.currency, 'created_at', i.created_at,
    'reading_started', i.read_started_at is not null, 'read_at', i.read_at, 'failure_reason', i.failure_reason,
    'line_count', (select count(*) from public.invoice_lines l where l.invoice_id = i.id)
  )
  from public.invoices i
  where i.id = p_invoice_id;
$$;

-- Numbers and dates as the reading hands them over, or null for anything else: a number that does not fit its
-- column once rounded to its scale (p_limit: under 1e9 for the numeric(12, 2) quantities and amounts, under 1e8 for a
-- numeric(12, 4) unit price), a date that is not a real day. So a misread number leaves its field empty for the
-- admin to fill instead of failing the whole reading.
create function engine.json_numeric(p_value jsonb, p_scale integer, p_limit numeric)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_number numeric;
begin
  if p_value is null or jsonb_typeof(p_value) <> 'number' then
    return null;
  end if;
  v_number := round((p_value #>> '{}')::numeric, p_scale);
  return case when abs(v_number) < p_limit then v_number end;
end;
$$;

create function engine.json_date(p_value jsonb)
returns date
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_value is null or jsonb_typeof(p_value) <> 'string' or (p_value #>> '{}') !~ '^\d{4}-\d{2}-\d{2}$' then
    return null;
  end if;
  return (p_value #>> '{}')::date;
exception
  when others then
    return null;
end;
$$;

revoke execute on function engine.invoice_alias_key(text), engine.invoice_match_text(text),
  engine.invoice_variant_numbers(text), engine.invoice_suggested_name(text), engine.invoice_suggested_unit(text),
  engine.invoice_match_line(uuid, text, text, text, text, numeric, numeric), engine.invoice_json(uuid),
  engine.json_numeric(jsonb, integer, numeric), engine.json_date(jsonb)
  from public, anon, authenticated;

-- The app ------------------------------------------------------------------------------------------------------------

-- Flow step 1: the invoice for pages the app uploaded under {clinic_id}/{invoice_id}/, status reading. The app makes
-- the id, so a retry after a lost answer finds the same invoice instead of making a second one. Receiving is
-- admin-only (PRD §2) and a write (MS-142).
create function public.invoice_create(
  p_clinic_id uuid,
  p_invoice_id uuid,
  p_source public.invoice_source,
  p_file_kind text,
  p_file_count integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_folder text := lower(p_clinic_id::text) || '/' || lower(p_invoice_id::text);
  v_files integer;
  v_bytes bigint;
begin
  if not coalesce(public.is_admin(p_clinic_id), false) then
    perform engine.fail('42501', 'Only an admin can receive deliveries');
  end if;
  if not public.clinic_can_write(p_clinic_id) then
    perform engine.fail('42501', 'The clinic is read-only until a payment method is added');
  end if;
  if p_source is distinct from 'camera' and p_source is distinct from 'file' then
    perform engine.fail('22023', 'An invoice is a photo or a file');
  end if;
  if p_file_kind is null or p_file_kind not in ('jpg', 'pdf') or coalesce(p_file_count, 0) not between 1 and 20
     or (p_file_kind = 'pdf' and p_file_count <> 1) then
    perform engine.fail('22023', 'An invoice has 1 to 20 JPEG pages, or one PDF');
  end if;
  if exists (select 1 from public.invoices i where i.id = p_invoice_id and i.clinic_id <> p_clinic_id) then
    perform engine.fail('42501', 'Only an admin can receive deliveries');
  end if;
  if not exists (select 1 from public.invoices i where i.id = p_invoice_id) then
    select count(*), coalesce(sum((o.metadata ->> 'size')::bigint), 0) into v_files, v_bytes
    from storage.objects o
    where o.bucket_id = 'invoices'
      and o.name in (select v_folder || '/page-' || n || '.' || p_file_kind from generate_series(1, p_file_count) n);
    if v_files <> p_file_count then
      perform engine.fail('22023', 'The pages did not finish uploading. Try again.');
    end if;
    if v_bytes > 20000000 then
      perform engine.fail('22023', 'The pages are over 20 MB');
    end if;
    insert into public.invoices (id, clinic_id, storage_path, source, status, created_by, file_kind, file_count)
    values (p_invoice_id, p_clinic_id, v_folder, p_source, 'reading', auth.uid(), p_file_kind, p_file_count)
    on conflict (id) do nothing;
  end if;
  return engine.invoice_json(p_invoice_id);
end;
$$;
revoke execute on function public.invoice_create(uuid, uuid, public.invoice_source, text, integer) from public, anon;
grant execute on function public.invoice_create(uuid, uuid, public.invoice_source, text, integer)
  to authenticated, service_role;

-- Review invoice as the reading state polls it (Appendix B `invoice`), for an admin of the invoice's clinic; a read,
-- so a read-only clinic's admin may call it too.
create function public.invoice_detail(p_invoice_id uuid)
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
  return engine.invoice_json(p_invoice_id);
end;
$$;
revoke execute on function public.invoice_detail(uuid) from public, anon;
grant execute on function public.invoice_detail(uuid) to authenticated, service_role;

-- Receive manually instead (the reading state's link): the invoice is set aside before the delivery is received by
-- hand, so it never comes back as a delivery waiting for review to be received a second time. An invoice already
-- received cannot be discarded.
create function public.invoice_discard(p_invoice_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invoice public.invoices;
begin
  select * into v_invoice from public.invoices i where i.id = p_invoice_id for update;
  if v_invoice.id is null or not coalesce(public.is_admin(v_invoice.clinic_id), false) then
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
revoke execute on function public.invoice_discard(uuid) from public, anon;
grant execute on function public.invoice_discard(uuid) to authenticated, service_role;

-- extract_invoice (service role) -------------------------------------------------------------------------------------

-- Claims an invoice for reading, once: the files to send and the clinic. Answers no row when it is already being read
-- or was read, so a second call reads nothing. The function checks the caller's token; this checks that the caller
-- is an admin of the invoice's clinic and that the clinic may write.
create function public.invoice_reading_start(p_invoice_id uuid, p_user_id uuid)
returns table (clinic_id uuid, storage_path text, file_kind text, file_count integer, started_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invoice public.invoices;
begin
  select * into v_invoice from public.invoices i where i.id = p_invoice_id for update;
  if v_invoice.id is null or not exists (
    select 1 from public.memberships m
    where m.clinic_id = v_invoice.clinic_id and m.user_id = p_user_id and m.role = 'admin' and m.status = 'active'
  ) then
    perform engine.fail('42501', 'Only an admin can receive deliveries');
  end if;
  if not public.clinic_can_write(v_invoice.clinic_id) then
    perform engine.fail('42501', 'The clinic is read-only until a payment method is added');
  end if;
  if v_invoice.status <> 'reading' or v_invoice.read_started_at is not null or v_invoice.file_kind is null then
    return;
  end if;
  update public.invoices i set read_started_at = now() where i.id = p_invoice_id;
  return query select v_invoice.clinic_id, v_invoice.storage_path, v_invoice.file_kind, v_invoice.file_count, now();
end;
$$;
revoke execute on function public.invoice_reading_start(uuid, uuid) from public, anon, authenticated;
grant execute on function public.invoice_reading_start(uuid, uuid) to service_role;

-- Flow steps 4 and 5: what the reader found (the extraction's JSON, checked by the function), saved with each line's
-- match, and the invoice ready to review with its alert, in one transaction. Does nothing for an invoice no longer
-- being read (it failed on time, or was discarded meanwhile) and answers null then.
create function public.invoice_reading_finish(p_invoice_id uuid, p_extraction jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invoice public.invoices;
  v_supplier text := left(nullif(btrim(p_extraction ->> 'supplier'), ''), 200);
  v_supplier_key text := engine.invoice_alias_key(nullif(btrim(p_extraction ->> 'supplier'), ''));
  v_currency text := upper(btrim(p_extraction ->> 'currency'));
  v_line jsonb;
  v_raw text;
  v_kind text;
  v_qty numeric;
  v_unit text;
  v_line_total numeric;
  v_expiry date;
  v_match record;
  v_n integer := 0;
begin
  select * into v_invoice from public.invoices i where i.id = p_invoice_id for update;
  if v_invoice.id is null or v_invoice.status <> 'reading' then
    return null;
  end if;
  if jsonb_typeof(p_extraction -> 'lines') is distinct from 'array'
     or not exists (
       select 1 from jsonb_array_elements(p_extraction -> 'lines') l where btrim(coalesce(l ->> 'raw', '')) <> ''
     ) then
    perform engine.fail('22023', 'A reading needs at least one line');
  end if;

  update public.invoices i
  set supplier = v_supplier,
      number = left(nullif(btrim(p_extraction ->> 'invoice_number'), ''), 60),
      invoice_date = engine.json_date(p_extraction -> 'invoice_date'),
      total = engine.json_numeric(p_extraction -> 'total', 2, 1e9),
      currency = case when v_currency ~ '^[A-Z]{3}$' then v_currency end,
      raw_extraction = p_extraction,
      status = 'ready',
      read_at = now()
  where i.id = p_invoice_id;

  for v_line in select l from jsonb_array_elements(p_extraction -> 'lines') l loop
    v_raw := left(btrim(coalesce(v_line ->> 'raw', '')), 300);
    continue when v_raw = '';
    v_n := v_n + 1;
    v_kind := case when v_line ->> 'kind' = 'fee' then 'fee' else 'product' end;
    v_qty := engine.json_numeric(v_line -> 'qty', 2, 1e9);
    v_unit := left(nullif(btrim(lower(v_line ->> 'unit')), ''), 30);
    v_line_total := engine.json_numeric(v_line -> 'line_total', 2, 1e9);
    v_expiry := date_trunc('month', engine.json_date(v_line -> 'expiry'))::date;
    select * into v_match
    from engine.invoice_match_line(v_invoice.clinic_id, v_supplier_key, v_raw, v_kind, v_unit, v_qty, v_line_total);
    insert into public.invoice_lines (
      clinic_id, invoice_id, n, raw, qty, unit, unit_price, line_total, lot, expiry_month, kind, state,
      product_id, suggested_product_id, match_score, suggested_name, suggested_unit
    ) values (
      v_invoice.clinic_id, p_invoice_id, v_n, v_raw, v_qty, v_unit, engine.json_numeric(v_line -> 'unit_price', 4, 1e8),
      v_line_total, left(nullif(btrim(v_line ->> 'lot'), ''), 60), v_expiry, v_kind, v_match.o_state,
      v_match.o_product_id, v_match.o_suggested_product_id, v_match.o_score, v_match.o_suggested_name,
      v_match.o_suggested_unit
    );
  end loop;

  insert into public.alerts (clinic_id, kind, invoice_id)
  values (v_invoice.clinic_id, 'invoice_ready', p_invoice_id)
  on conflict do nothing;
  return engine.invoice_json(p_invoice_id);
end;
$$;
revoke execute on function public.invoice_reading_finish(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.invoice_reading_finish(uuid, jsonb) to service_role;

-- A reading that failed: the invoice stays failed with the reason (the screen offers a clearer photo or receiving by
-- hand). An invoice no longer being read is left as it is.
create function public.invoice_reading_fail(p_invoice_id uuid, p_reason text)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.invoices i
  set status = 'failed', failure_reason = p_reason, read_at = now()
  where i.id = p_invoice_id and i.status = 'reading';
$$;
revoke execute on function public.invoice_reading_fail(uuid, text) from public, anon, authenticated;
grant execute on function public.invoice_reading_fail(uuid, text) to service_role;

-- Each minute: a reading that never started, or ran past its 60 seconds, is failed (with 15 seconds' grace for the
-- function's own answer), so no invoice stays "Reading invoice" for good.
create function engine.invoice_reading_timeout()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.invoices i
  set status = 'failed', failure_reason = 'timeout', read_at = now()
  where i.status = 'reading' and coalesce(i.read_started_at, i.created_at) < now() - interval '75 seconds';
$$;
revoke execute on function engine.invoice_reading_timeout() from public, anon, authenticated;

select cron.schedule('invoice-reading-timeout', '* * * * *', $$select engine.invoice_reading_timeout()$$);
