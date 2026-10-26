-- MS-130 · Reviewing an invoice's lines: invoice_detail answers the lines with what the screen draws; a Possible match
-- is matched or created, a New product created or matched, a fee ignored or matched; a settled line reopens in the
-- state it was read in, which never changes; Matched and Created lines keep a lot and an expiry month; only an admin of
-- a clinic that may write settles a line, only while its invoice waits for review, and never through the table; and
-- no stock moves.
begin;
select plan(54);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000130001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@review.test'),
  ('00000000-0000-4000-8000-000000130002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@review.test'),
  ('00000000-0000-4000-8000-000000130003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'olivia@review.test'),
  ('00000000-0000-4000-8000-000000130004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dana@review.test');
insert into public.clinics (id, name, country, currency, time_zone, trial_ends_at) values
  ('00000000-0000-4000-8000-000000130011', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days'),
  ('00000000-0000-4000-8000-000000130012', 'Lapsed Dental', 'CA', 'CAD', 'America/Toronto', now() - interval '1 day'),
  ('00000000-0000-4000-8000-000000130013', 'Other Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000130011', '00000000-0000-4000-8000-000000130001', 'sarah@review.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000130011', '00000000-0000-4000-8000-000000130002', 'michael@review.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000130012', '00000000-0000-4000-8000-000000130003', 'olivia@review.test', 'Olivia Grant', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000130013', '00000000-0000-4000-8000-000000130004', 'dana@review.test', 'Dana Lee', 'admin', 'active');
insert into public.products (id, clinic_id, name, unit, pack_unit, pack_size, archived_at) values
  ('00000000-0000-4000-8000-000000130021', '00000000-0000-4000-8000-000000130011', 'Septocaine 4% 1:100,000', 'cartridges', 'box', 50, null),
  ('00000000-0000-4000-8000-000000130022', '00000000-0000-4000-8000-000000130011', 'Endo file kit #15-40', 'kits', null, null, null),
  ('00000000-0000-4000-8000-000000130023', '00000000-0000-4000-8000-000000130011', 'Needle 27g short', 'needles', 'box', 100, null),
  ('00000000-0000-4000-8000-000000130024', '00000000-0000-4000-8000-000000130011', 'Old gauze', 'packs', null, null, now()),
  -- What New product's "Create and use for this line" created, before the line uses it.
  ('00000000-0000-4000-8000-000000130025', '00000000-0000-4000-8000-000000130011', 'Tempbond NE', 'packs', null, null, null),
  ('00000000-0000-4000-8000-000000130026', '00000000-0000-4000-8000-000000130013', 'Other gloves', 'boxes', null, null, null),
  ('00000000-0000-4000-8000-000000130027', '00000000-0000-4000-8000-000000130012', 'Lapsed gloves', 'boxes', null, null, null);
insert into public.batches (clinic_id, product_id, qty) values
  ('00000000-0000-4000-8000-000000130011', '00000000-0000-4000-8000-000000130021', 54);

-- The frames' invoice (f23), read and waiting for review; Lapsed Dental's, ready too but read-only; and one set aside.
insert into public.invoices (id, clinic_id, storage_path, source, status, supplier, number, total, created_by, file_kind, file_count) values
  ('00000000-0000-4000-8000-000000130031', '00000000-0000-4000-8000-000000130011',
   '00000000-0000-4000-8000-000000130011/00000000-0000-4000-8000-000000130031', 'camera', 'ready', 'Patterson', 'INV-10092', 449,
   '00000000-0000-4000-8000-000000130001', 'jpg', 1),
  ('00000000-0000-4000-8000-000000130032', '00000000-0000-4000-8000-000000130012',
   '00000000-0000-4000-8000-000000130012/00000000-0000-4000-8000-000000130032', 'camera', 'ready', 'Patterson', 'INV-2', 10,
   '00000000-0000-4000-8000-000000130003', 'jpg', 1),
  ('00000000-0000-4000-8000-000000130033', '00000000-0000-4000-8000-000000130011',
   '00000000-0000-4000-8000-000000130011/00000000-0000-4000-8000-000000130033', 'camera', 'discarded', 'Patterson', 'INV-3', 10,
   '00000000-0000-4000-8000-000000130001', 'jpg', 1);
insert into public.invoice_lines (id, clinic_id, invoice_id, n, raw, qty, unit, unit_price, line_total, kind, state,
  product_id, suggested_product_id, suggested_name, suggested_unit, lot, expiry_month) values
  ('00000000-0000-4000-8000-000000130041', '00000000-0000-4000-8000-000000130011', '00000000-0000-4000-8000-000000130031', 1,
   'SEPTO 4% 1:100K 50/BX', 5, 'boxes', 49.80, 249.00, 'product', 'matched', '00000000-0000-4000-8000-000000130021', null, null, null,
   'B441', '2028-03-01'),
  ('00000000-0000-4000-8000-000000130042', '00000000-0000-4000-8000-000000130011', '00000000-0000-4000-8000-000000130031', 2,
   'ENDO FILE KIT 15-40 21MM', 4, 'boxes', 45.00, 180.00, 'product', 'possible_match', null, '00000000-0000-4000-8000-000000130022', null, null,
   null, null),
  ('00000000-0000-4000-8000-000000130043', '00000000-0000-4000-8000-000000130011', '00000000-0000-4000-8000-000000130031', 3,
   'TEMPBOND NE 1PK', 1, 'pack', 26.40, 26.40, 'product', 'new_product', null, null, 'Tempbond NE', 'packs', null, null),
  ('00000000-0000-4000-8000-000000130044', '00000000-0000-4000-8000-000000130011', '00000000-0000-4000-8000-000000130031', 4,
   'HANDLING / FUEL SURCHARGE', 1, null, 4.80, 4.80, 'fee', 'needs_review', null, null, null, null, null, null),
  ('00000000-0000-4000-8000-000000130045', '00000000-0000-4000-8000-000000130012', '00000000-0000-4000-8000-000000130032', 1,
   'NITRILE GLOVES M', 1, 'box', 10, 10, 'product', 'new_product', null, null, 'Nitrile gloves M', 'boxes', null, null),
  ('00000000-0000-4000-8000-000000130046', '00000000-0000-4000-8000-000000130011', '00000000-0000-4000-8000-000000130033', 1,
   'NITRILE GLOVES M', 1, 'box', 10, 10, 'product', 'new_product', null, null, 'Nitrile gloves M', 'boxes', null, null);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

-- Stock as receiving would change it; reviewing must leave it as it is.
create function pg_temp.stock() returns text language sql as $$
  select format('%s batches, %s units, %s ledger rows, %s open items, %s To buy lines, %s products',
    (select count(*) from public.batches), (select coalesce(sum(qty), 0) from public.batches),
    (select count(*) from public.transactions), (select count(*) from public.open_items),
    (select count(*) from public.to_buy_items), (select count(*) from public.products))
$$;
create temp table stock_before as select pg_temp.stock() as stock;

-- A line as the table keeps it: state, the state it was read in, product, lot and expiry month.
create function pg_temp.line(p_id uuid) returns text language sql as $$
  select format('%s (read %s) · %s · %s · %s', l.state, l.read_state, coalesce(p.name, 'no product'),
    coalesce(l.lot, 'no lot'), coalesce(l.expiry_month::text, 'no expiry'))
  from public.invoice_lines l left join public.products p on p.id = l.product_id where l.id = p_id
$$;

-- Who may call what ----------------------------------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'public.invoice_line_match(uuid, uuid)', 'execute')
  and not has_function_privilege('anon', 'public.invoice_line_create(uuid, uuid)', 'execute')
  and not has_function_privilege('anon', 'public.invoice_line_skip(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.invoice_line_reopen(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.invoice_line_batch(uuid, text, date)', 'execute'),
  'anon settles no line');
select ok(has_function_privilege('authenticated', 'public.invoice_line_match(uuid, uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.invoice_line_create(uuid, uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.invoice_line_skip(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.invoice_line_reopen(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.invoice_line_batch(uuid, text, date)', 'execute'),
  'members call the five line functions (admins only, checked inside)');
select ok(not has_table_privilege('authenticated', 'public.invoice_lines', 'update')
  and not has_table_privilege('authenticated', 'public.invoices', 'update'),
  'invoices and lines are no longer updated directly');

-- invoice_detail -------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000130001');
select is(jsonb_array_length(public.invoice_detail('00000000-0000-4000-8000-000000130031') -> 'lines'), 4,
  'the admin reads the invoice with its four lines');
select is((public.invoice_detail('00000000-0000-4000-8000-000000130031') -> 'lines' -> 0) - 'id',
  jsonb_build_object('n', 1, 'raw', 'SEPTO 4% 1:100K 50/BX', 'qty', 5.00, 'unit', 'boxes', 'unit_price', 49.8000,
    'line_total', 249.00, 'kind', 'product', 'state', 'matched', 'read_state', 'matched',
    'product_id', '00000000-0000-4000-8000-000000130021', 'product_name', 'Septocaine 4% 1:100,000',
    'suggested_product_id', null, 'suggested_product_name', null, 'suggested_name', 'Septo 4% 1:100K',
    'suggested_unit', 'boxes', 'lot', 'B441', 'expiry_month', '2028-03-01'),
  'a Matched line: what was read, its product, and the lot and expiry month it came with');
select results_eq(
  $$ select l ->> 'n', l ->> 'state', l ->> 'suggested_product_name', l ->> 'suggested_name', l ->> 'suggested_unit', l ->> 'kind'
     from jsonb_array_elements(public.invoice_detail('00000000-0000-4000-8000-000000130031') -> 'lines') l $$,
  $$ values ('1', 'matched', null, 'Septo 4% 1:100K', 'boxes', 'product'),
            ('2', 'possible_match', 'Endo file kit #15-40', 'Endo file kit 15-40 21MM', 'boxes', 'product'),
            ('3', 'new_product', null, 'Tempbond NE', 'packs', 'product'),
            ('4', 'needs_review', null, 'Handling / fuel surcharge', 'units', 'fee') $$,
  'in reading order: the product a Possible match suggests, and the name and unit New product starts from on every line');
reset role;

-- Who settles a line ---------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000130002');
select throws_ok($$ select public.invoice_line_match('00000000-0000-4000-8000-000000130042', '00000000-0000-4000-8000-000000130022') $$,
  '42501', 'Only an admin can receive deliveries', 'Staff settle no line');
select throws_ok($$ select public.invoice_line_skip('00000000-0000-4000-8000-000000130044') $$,
  '42501', 'Only an admin can receive deliveries', 'nor ignore a fee');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000130004');
select throws_ok($$ select public.invoice_line_match('00000000-0000-4000-8000-000000130042', '00000000-0000-4000-8000-000000130022') $$,
  '42501', 'Only an admin can receive deliveries', 'another clinic''s admin settles none of this clinic''s lines');
select throws_ok($$ select public.invoice_line_reopen('00000000-0000-4000-8000-000000130041') $$,
  '42501', 'Only an admin can receive deliveries', 'nor reopens them');
select throws_ok($$ select public.invoice_line_match('00000000-0000-4000-8000-000000130099', '00000000-0000-4000-8000-000000130022') $$,
  '42501', 'Only an admin can receive deliveries', 'and a line that does not exist is refused the same way');
reset role;

-- A read-only clinic (MS-142) settles nothing, whatever the function.
select pg_temp.act_as('00000000-0000-4000-8000-000000130003');
select throws_ok($$ select public.invoice_line_match('00000000-0000-4000-8000-000000130045', '00000000-0000-4000-8000-000000130027') $$,
  '42501', 'The clinic is read-only until a payment method is added', 'a read-only clinic matches no line');
select throws_ok($$ select public.invoice_line_create('00000000-0000-4000-8000-000000130045', '00000000-0000-4000-8000-000000130027') $$,
  '42501', 'The clinic is read-only until a payment method is added', 'creates none');
select throws_ok($$ select public.invoice_line_skip('00000000-0000-4000-8000-000000130045') $$,
  '42501', 'The clinic is read-only until a payment method is added', 'ignores none');
select throws_ok($$ select public.invoice_line_reopen('00000000-0000-4000-8000-000000130045') $$,
  '42501', 'The clinic is read-only until a payment method is added', 'reopens none');
select throws_ok($$ select public.invoice_line_batch('00000000-0000-4000-8000-000000130045', 'L1', '2028-01-01') $$,
  '42501', 'The clinic is read-only until a payment method is added', 'and keeps no lot or expiry');
select is((public.invoice_detail('00000000-0000-4000-8000-000000130032') -> 'lines' -> 0) ->> 'state', 'new_product',
  'but its admin still reads the invoice');
reset role;

-- Possible match: Yes, match, and the badge back -------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000130001');
select is(public.invoice_line_match('00000000-0000-4000-8000-000000130042', '00000000-0000-4000-8000-000000130022') ->> 'product_name',
  'Endo file kit #15-40', 'Yes, match answers the line with its product');
select is(pg_temp.line('00000000-0000-4000-8000-000000130042'), 'matched (read possible_match) · Endo file kit #15-40 · no lot · no expiry',
  'the Possible match is Matched, and keeps the state it was read in (MS-147''s matched share)');
select throws_ok($$ select public.invoice_line_match('00000000-0000-4000-8000-000000130042', '00000000-0000-4000-8000-000000130023') $$,
  '22023', 'This line is already resolved.', 'a resolved line is not matched again');
select is(public.invoice_line_reopen('00000000-0000-4000-8000-000000130042') ->> 'state', 'possible_match', 'its badge reopens it');
select is(pg_temp.line('00000000-0000-4000-8000-000000130042'), 'possible_match (read possible_match) · no product · no lot · no expiry',
  'as it was read, the product dropped and the suggestion kept');
select is(public.invoice_line_reopen('00000000-0000-4000-8000-000000130042') ->> 'state', 'possible_match',
  'reopening a line already in the state it was read in changes nothing');
select is(public.invoice_line_reopen('00000000-0000-4000-8000-000000130041') ->> 'product_name', 'Septocaine 4% 1:100,000',
  'a line read as Matched stays Matched with its product');
select throws_ok($$ select public.invoice_line_skip('00000000-0000-4000-8000-000000130042') $$,
  '22023', 'This line cannot be resolved that way.', 'a Possible match is not ignored');

-- Products a line can become ---------------------------------------------------------------------------------------------
select throws_ok($$ select public.invoice_line_match('00000000-0000-4000-8000-000000130043', '00000000-0000-4000-8000-000000130024') $$,
  '22023', 'This product was deleted.', 'a deleted product is no match');
select throws_ok($$ select public.invoice_line_match('00000000-0000-4000-8000-000000130043', '00000000-0000-4000-8000-000000130026') $$,
  '22023', 'Choose a product for this line.', 'nor another clinic''s');
select throws_ok($$ select public.invoice_line_create('00000000-0000-4000-8000-000000130043', null) $$,
  '22023', 'Choose a product for this line.', 'and a line is not Created without a product');

-- New product: Add new (Created), back, then Pick existing (Matched) -------------------------------------------------------
select is(public.invoice_line_create('00000000-0000-4000-8000-000000130043', '00000000-0000-4000-8000-000000130025') ->> 'state',
  'created', 'Create and use for this line makes the line Created');
select is(pg_temp.line('00000000-0000-4000-8000-000000130043'), 'created (read new_product) · Tempbond NE · no lot · no expiry',
  'as the product the sheet created');
select is(public.invoice_line_reopen('00000000-0000-4000-8000-000000130043') ->> 'state', 'new_product', 'its badge reopens it');
select is((select archived_at from public.products where id = '00000000-0000-4000-8000-000000130025'), null,
  'and the product created stays with the clinic''s products');
select is(public.invoice_line_match('00000000-0000-4000-8000-000000130043', '00000000-0000-4000-8000-000000130023') ->> 'state',
  'matched', 'Pick existing matches a New product to a product the clinic has');
select is(pg_temp.line('00000000-0000-4000-8000-000000130043'), 'matched (read new_product) · Needle 27g short · no lot · no expiry',
  'which reopens to New product too');

-- Needs review: Ignore (Skipped), Undo, then Pick product (Matched) ------------------------------------------------------
select throws_ok($$ select public.invoice_line_create('00000000-0000-4000-8000-000000130044', '00000000-0000-4000-8000-000000130025') $$,
  '22023', 'This line cannot be resolved that way.', 'a fee is not created as a product');
select is(public.invoice_line_skip('00000000-0000-4000-8000-000000130044') ->> 'state', 'skipped', 'Ignore skips the fee');
select is(pg_temp.line('00000000-0000-4000-8000-000000130044'), 'skipped (read needs_review) · no product · no lot · no expiry',
  'which goes into no stock');
select is(public.invoice_line_reopen('00000000-0000-4000-8000-000000130044') ->> 'state', 'needs_review', 'Undo reopens it');
select is(public.invoice_line_match('00000000-0000-4000-8000-000000130044', '00000000-0000-4000-8000-000000130023') ->> 'state',
  'matched', 'and Pick product matches it to a product');

-- Lot and expiry -----------------------------------------------------------------------------------------------------------
select is(public.invoice_line_batch('00000000-0000-4000-8000-000000130041', '  A112  ', '2027-03-17') - 'id' - 'suggested_name' - 'suggested_unit'
  - 'raw' - 'qty' - 'unit' - 'unit_price' - 'line_total' - 'kind' - 'n' - 'product_id' - 'suggested_product_id' - 'suggested_product_name',
  jsonb_build_object('state', 'matched', 'read_state', 'matched', 'product_name', 'Septocaine 4% 1:100,000', 'lot', 'A112',
    'expiry_month', '2027-03-01'),
  'the lot is kept trimmed and the expiry as its month');
select is(pg_temp.line('00000000-0000-4000-8000-000000130042'), 'possible_match (read possible_match) · no product · no lot · no expiry',
  'other lines keep theirs');
select is(public.invoice_line_batch('00000000-0000-4000-8000-000000130041', '   ', null) ->> 'lot', null, 'an empty lot is no lot');
select is(pg_temp.line('00000000-0000-4000-8000-000000130041'), 'matched (read matched) · Septocaine 4% 1:100,000 · no lot · no expiry',
  'and no month is no expiry: Missing expiry once received');
select throws_ok($$ select public.invoice_line_batch('00000000-0000-4000-8000-000000130041', repeat('L', 61), null) $$,
  '22023', 'Keep the lot to 60 characters.', 'a lot holds 60 characters');
select is(public.invoice_line_batch('00000000-0000-4000-8000-000000130042', 'E7', '2027-09-01') ->> 'lot', 'E7',
  'a line waiting for its choice keeps a lot typed just before it was reopened');

-- The table, directly -------------------------------------------------------------------------------------------------------
select throws_ok($$ update public.invoice_lines set state = 'skipped' where id = '00000000-0000-4000-8000-000000130041' $$,
  '42501', null, 'an admin no longer updates a line directly');
select throws_ok($$ update public.invoices set status = 'confirmed' where id = '00000000-0000-4000-8000-000000130031' $$,
  '42501', null, 'nor an invoice');

-- An invoice no longer waiting for review ---------------------------------------------------------------------------------
select throws_ok($$ select public.invoice_line_match('00000000-0000-4000-8000-000000130046', '00000000-0000-4000-8000-000000130023') $$,
  '22023', 'This invoice is no longer waiting for review.', 'a discarded invoice''s lines stay as they are');
select lives_ok($$ select public.invoice_discard('00000000-0000-4000-8000-000000130031') $$, 'Discard invoice sets the invoice aside');
select throws_ok($$ select public.invoice_line_reopen('00000000-0000-4000-8000-000000130044') $$,
  '22023', 'This invoice is no longer waiting for review.', 'after which no line is settled or reopened');
select throws_ok($$ select public.invoice_line_batch('00000000-0000-4000-8000-000000130041', 'X', null) $$,
  '22023', 'This invoice is no longer waiting for review.', 'nor given a lot');
select is(jsonb_array_length(public.invoice_detail('00000000-0000-4000-8000-000000130031') -> 'lines'), 4,
  'and the invoice still reads with its lines');
reset role;

select results_eq(
  $$ select n, read_state::text from public.invoice_lines where invoice_id = '00000000-0000-4000-8000-000000130031' order by n $$,
  $$ values (1, 'matched'), (2, 'possible_match'), (3, 'new_product'), (4, 'needs_review') $$,
  'through every choice, each line keeps the state it was read in');
select is(pg_temp.stock(), (select stock from stock_before), 'and no batch, ledger row, open item, To buy line or product changed');

select * from finish();
rollback;
