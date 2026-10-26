-- MS-131 · Confirm and receive an invoice: invoice_confirm receives every Matched and Created line in counted units on
-- the batch of its lot and expiry, at the cost per counted unit and referenced "Invoice {number}", moves the products'
-- To buy and Ordered lines to Received, learns the supplier's words (the next delivery matches them at once), fills an
-- empty supplier and confirms the invoice; a replay answers the first action; Undo within 10 seconds, by the same admin,
-- puts every quantity and all the rest back and the invoice waits for review again; a received invoice keeps its pages
-- and refuses a discard, a line change and a second confirmation; only an admin of a clinic that may write receives, an
-- unresolved line or a deleted product stops it, and a delivery in another currency keeps the clinic's cost; Activity's
-- History names the invoice each receipt came from.
begin;
select plan(56);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000131001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@confirm.test'),
  ('00000000-0000-4000-8000-000000131002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@confirm.test'),
  ('00000000-0000-4000-8000-000000131003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'olivia@confirm.test'),
  ('00000000-0000-4000-8000-000000131004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dana@confirm.test'),
  ('00000000-0000-4000-8000-000000131005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'daniel@confirm.test');
insert into public.clinics (id, name, country, currency, time_zone, trial_ends_at) values
  ('00000000-0000-4000-8000-000000131011', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days'),
  ('00000000-0000-4000-8000-000000131012', 'Lapsed Dental', 'CA', 'CAD', 'America/Toronto', now() - interval '1 day'),
  ('00000000-0000-4000-8000-000000131013', 'Other Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131001', 'sarah@confirm.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131002', 'michael@confirm.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000131012', '00000000-0000-4000-8000-000000131003', 'olivia@confirm.test', 'Olivia Grant', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000131013', '00000000-0000-4000-8000-000000131004', 'dana@confirm.test', 'Dana Lee', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131005', 'daniel@confirm.test', 'Dr. Daniel Kim', 'admin', 'active');

-- Septocaine comes in boxes of 50 cartridges and has a supplier; Endo file kit is counted by the kit, Low and ordered;
-- Tempbond NE was created on its invoice line; Rubber dam is out of stock and on To buy; Nitrile gloves come in cases of
-- 10 boxes and have an empty supplier; Old gauze was deleted.
insert into public.products (id, clinic_id, name, unit, pack_unit, pack_size, minimum, target, supplier, last_unit_cost, archived_at) values
  ('00000000-0000-4000-8000-000000131021', '00000000-0000-4000-8000-000000131011', 'Septocaine 4% 1:100,000', 'cartridges', 'box', 50, 20, 60, 'Henry Schein', 3.06, null),
  ('00000000-0000-4000-8000-000000131022', '00000000-0000-4000-8000-000000131011', 'Endo file kit #15-40', 'kits', null, null, 3, 5, null, 40, null),
  ('00000000-0000-4000-8000-000000131023', '00000000-0000-4000-8000-000000131011', 'Tempbond NE', 'packs', null, null, 0, 0, null, null, null),
  ('00000000-0000-4000-8000-000000131024', '00000000-0000-4000-8000-000000131011', 'Rubber dam latex-free', 'sheets', null, null, 10, 36, 'Henry Schein', null, null),
  ('00000000-0000-4000-8000-000000131025', '00000000-0000-4000-8000-000000131011', 'Old gauze', 'packs', null, null, 0, 0, null, null, now()),
  ('00000000-0000-4000-8000-000000131026', '00000000-0000-4000-8000-000000131011', 'Nitrile gloves M', 'boxes', 'case', 10, 6, 20, '', 9, null),
  ('00000000-0000-4000-8000-000000131027', '00000000-0000-4000-8000-000000131012', 'Lapsed gloves', 'boxes', null, null, 0, 0, null, null, null);
insert into public.batches (clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131021', '2027-01-01', 'A112', 54),
  ('00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131022', null, null, 1),
  ('00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131026', null, null, 8);
insert into public.to_buy_items (id, clinic_id, product_id, qty, source, status, ordered_at, ordered_by, created_at) values
  ('00000000-0000-4000-8000-000000131041', '00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131022', 4, 'auto',
   'ordered', now() - interval '1 day', '00000000-0000-4000-8000-000000131001', now() - interval '2 days'),
  ('00000000-0000-4000-8000-000000131042', '00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131024', 36, 'auto',
   'to_buy', null, null, now() - interval '1 day');
-- Patterson's words for Septocaine, from an earlier delivery, and for Rubber dam, pointing at the gloves by mistake.
insert into public.supplier_aliases (clinic_id, supplier, raw_text_normalized, product_id) values
  ('00000000-0000-4000-8000-000000131011', 'patterson', 'septo 4 1 100k 50 bx', '00000000-0000-4000-8000-000000131021'),
  ('00000000-0000-4000-8000-000000131011', 'patterson', 'rubber dam latex free', '00000000-0000-4000-8000-000000131026');

-- 31: f23's invoice with every line resolved, and a few more; 32: a line still waiting; 33: a line on a product deleted
-- since; 34: Lapsed Dental's, read-only; 35: Patterson's next delivery, being read; 36: Benco's, invoiced in dollars.
insert into public.invoices (id, clinic_id, storage_path, source, status, supplier, number, total, currency, created_by, created_at, file_kind, file_count) values
  ('00000000-0000-4000-8000-000000131031', '00000000-0000-4000-8000-000000131011',
   '00000000-0000-4000-8000-000000131011/00000000-0000-4000-8000-000000131031', 'camera', 'ready', 'Patterson', 'INV-10092', 449, 'CAD',
   '00000000-0000-4000-8000-000000131001', now() - interval '10 minutes', 'jpg', 1),
  ('00000000-0000-4000-8000-000000131032', '00000000-0000-4000-8000-000000131011',
   '00000000-0000-4000-8000-000000131011/00000000-0000-4000-8000-000000131032', 'camera', 'ready', 'Patterson', 'INV-2', 10, null,
   '00000000-0000-4000-8000-000000131001', now(), 'jpg', 1),
  ('00000000-0000-4000-8000-000000131033', '00000000-0000-4000-8000-000000131011',
   '00000000-0000-4000-8000-000000131011/00000000-0000-4000-8000-000000131033', 'camera', 'ready', 'Patterson', 'INV-3', 10, null,
   '00000000-0000-4000-8000-000000131001', now(), 'jpg', 1),
  ('00000000-0000-4000-8000-000000131034', '00000000-0000-4000-8000-000000131012',
   '00000000-0000-4000-8000-000000131012/00000000-0000-4000-8000-000000131034', 'camera', 'ready', 'Patterson', 'INV-4', 10, null,
   '00000000-0000-4000-8000-000000131003', now(), 'jpg', 1),
  ('00000000-0000-4000-8000-000000131035', '00000000-0000-4000-8000-000000131011',
   '00000000-0000-4000-8000-000000131011/00000000-0000-4000-8000-000000131035', 'camera', 'reading', null, null, null, null,
   '00000000-0000-4000-8000-000000131001', now(), 'jpg', 1),
  ('00000000-0000-4000-8000-000000131036', '00000000-0000-4000-8000-000000131011',
   '00000000-0000-4000-8000-000000131011/00000000-0000-4000-8000-000000131036', 'camera', 'ready', 'Benco', 'B-7', 12, 'USD',
   '00000000-0000-4000-8000-000000131001', now(), 'jpg', 1);
insert into public.invoice_lines (id, clinic_id, invoice_id, n, raw, qty, unit, unit_price, line_total, kind, state, read_state,
  product_id, lot, expiry_month) values
  ('00000000-0000-4000-8000-000000131051', '00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131031', 1,
   'SEPTO 4% 1:100K 50/BX', 5, 'boxes', 49.80, 249.00, 'product', 'matched', 'matched', '00000000-0000-4000-8000-000000131021', 'B441', '2028-03-01'),
  ('00000000-0000-4000-8000-000000131052', '00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131031', 2,
   'ENDO FILE KIT 15-40 21MM', 4, 'boxes', 45.00, 180.00, 'product', 'matched', 'possible_match', '00000000-0000-4000-8000-000000131022', null, null),
  ('00000000-0000-4000-8000-000000131053', '00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131031', 3,
   'TEMPBOND NE 1PK', 1, 'pack', 26.40, 26.40, 'product', 'created', 'new_product', '00000000-0000-4000-8000-000000131023', null, null),
  ('00000000-0000-4000-8000-000000131054', '00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131031', 4,
   'HANDLING / FUEL SURCHARGE', 1, null, 4.80, 4.80, 'fee', 'skipped', 'needs_review', null, null, null),
  ('00000000-0000-4000-8000-000000131055', '00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131031', 5,
   'RUBBER DAM LATEX FREE', 5, 'sheets', 1.10, 5.50, 'product', 'matched', 'possible_match', '00000000-0000-4000-8000-000000131024', null, null),
  ('00000000-0000-4000-8000-000000131056', '00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131031', 6,
   'NITRILE GLOVES M 10/CS', 2, 'CS', 95.00, 190.00, 'product', 'matched', 'matched', '00000000-0000-4000-8000-000000131026', null, null),
  ('00000000-0000-4000-8000-000000131057', '00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131031', 7,
   'NITRILE GLOVES M BACKORDER', null, 'CS', null, null, 'product', 'matched', 'matched', '00000000-0000-4000-8000-000000131026', null, null),
  ('00000000-0000-4000-8000-000000131058', '00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131032', 1,
   'COTTON ROLLS', 1, 'bag', 3, 3, 'product', 'possible_match', 'possible_match', null, null, null),
  ('00000000-0000-4000-8000-000000131059', '00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131033', 1,
   'SHIPPING', 1, null, 5, 5, 'fee', 'skipped', 'needs_review', null, null, null),
  ('00000000-0000-4000-8000-000000131060', '00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131033', 2,
   'GAUZE 2X2', 1, 'pack', 5, 5, 'product', 'matched', 'matched', '00000000-0000-4000-8000-000000131025', null, null),
  ('00000000-0000-4000-8000-000000131061', '00000000-0000-4000-8000-000000131012', '00000000-0000-4000-8000-000000131034', 1,
   'LAPSED GLOVES', 1, 'box', 10, 10, 'product', 'matched', 'matched', '00000000-0000-4000-8000-000000131027', null, null),
  ('00000000-0000-4000-8000-000000131062', '00000000-0000-4000-8000-000000131011', '00000000-0000-4000-8000-000000131036', 1,
   'NITRILE GLOVES M', 1, 'boxes', 12, 12, 'product', 'matched', 'matched', '00000000-0000-4000-8000-000000131026', null, null);
insert into public.alerts (clinic_id, kind, invoice_id, opened_at) values
  ('00000000-0000-4000-8000-000000131011', 'invoice_ready', '00000000-0000-4000-8000-000000131031', now() - interval '9 minutes');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
-- An idempotency key by its two last digits.
create function pg_temp.k(p_n text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000001319' || p_n)::uuid
$$;
create function pg_temp.p(p_n text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000001310' || p_n)::uuid
$$;
create function pg_temp.qty(p_product text) returns numeric language sql as $$
  select coalesce((select quantity from public.product_stock where product_id = pg_temp.p(p_product)), 0)
$$;
-- Every product's stock, cost and supplier, as Inventory, Inventory value and Edit product read them.
create function pg_temp.products() returns text language sql as $$
  select string_agg(format('%s: %s at %s from %s', p.name, coalesce(s.quantity, 0), coalesce(p.last_unit_cost::text, 'no cost'),
    coalesce(nullif(p.supplier, ''), case when p.supplier = '' then 'empty' else 'nobody' end)), '; ' order by p.name)
  from public.products p left join public.product_stock s on s.product_id = p.id
  where p.clinic_id = '00000000-0000-4000-8000-000000131011' and p.archived_at is null
$$;
create function pg_temp.to_buy() returns text language sql as $$
  select string_agg(format('%s %s %s%s%s', p.name, t.status, t.qty,
    case when t.received_at is not null then ' received' else '' end,
    case when t.invoice_id is not null then ' on its invoice' else '' end), '; ' order by p.name, t.created_at)
  from public.to_buy_items t join public.products p on p.id = t.product_id
  where t.product_id in (pg_temp.p('22'), pg_temp.p('24'))
$$;
create function pg_temp.aliases() returns text language sql as $$
  select string_agg(format('%s "%s" %s', a.supplier, a.raw_text_normalized, p.name), '; ' order by a.raw_text_normalized)
  from public.supplier_aliases a join public.products p on p.id = a.product_id
  where a.clinic_id = '00000000-0000-4000-8000-000000131011' and a.supplier = 'patterson'
$$;
create temp table before_confirm as select pg_temp.products() as products, pg_temp.to_buy() as to_buy, pg_temp.aliases() as aliases;

-- Who may call it ------------------------------------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'public.invoice_confirm(uuid, uuid)', 'execute'), 'anon receives nothing');
select ok(has_function_privilege('authenticated', 'public.invoice_confirm(uuid, uuid)', 'execute'),
  'members call invoice_confirm (admins only, checked inside)');

select pg_temp.act_as('00000000-0000-4000-8000-000000131002');
select throws_ok($$ select public.invoice_confirm('00000000-0000-4000-8000-000000131031', pg_temp.k('01')) $$,
  '42501', 'Only an admin can receive deliveries', 'Staff receive no delivery');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000131004');
select throws_ok($$ select public.invoice_confirm('00000000-0000-4000-8000-000000131031', pg_temp.k('02')) $$,
  '42501', 'Only an admin can receive deliveries', 'nor another clinic''s admin');
select throws_ok($$ select public.invoice_confirm('00000000-0000-4000-8000-000000131099', pg_temp.k('03')) $$,
  '42501', 'Only an admin can receive deliveries', 'and an invoice that does not exist is refused the same way');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000131003');
select throws_ok($$ select public.invoice_confirm('00000000-0000-4000-8000-000000131034', pg_temp.k('04')) $$,
  '42501', 'The clinic is read-only until a payment method is added', 'a read-only clinic receives nothing (MS-142)');
reset role;

-- What stops a confirmation ---------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000131001');
select throws_ok($$ select public.invoice_confirm('00000000-0000-4000-8000-000000131032', pg_temp.k('05')) $$,
  '22023', 'Resolve every line to continue.', 'a line still waiting for its choice stops it');
select throws_ok($$ select public.invoice_confirm('00000000-0000-4000-8000-000000131033', pg_temp.k('06')) $$,
  '22023', 'Old gauze was deleted. Choose another product for line 2.', 'and so does a product deleted since its line was settled');
select throws_ok($$ select public.invoice_confirm('00000000-0000-4000-8000-000000131031', null) $$,
  '22023', 'an idempotency key is required', 'a confirmation carries its key');
-- The admin uploads the pages of the invoices waiting for review.
insert into storage.objects (bucket_id, name) values
  ('invoices', '00000000-0000-4000-8000-000000131011/00000000-0000-4000-8000-000000131031/page-1.jpg'),
  ('invoices', '00000000-0000-4000-8000-000000131011/00000000-0000-4000-8000-000000131032/page-1.jpg');
reset role;
select is((select count(*)::integer from public.stock_actions where idempotency_key in (
    select pg_temp.k(n) from unnest(array['01', '02', '03', '04', '05', '06']) n)), 0,
  'a refused confirmation leaves no action behind');
select is(pg_temp.products(), (select products from before_confirm), 'and changes no stock, cost or supplier');

-- Confirm & receive the frames' invoice ---------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000131001');
select set_config('test.confirm', public.invoice_confirm('00000000-0000-4000-8000-000000131031', pg_temp.k('10'))::text, true);
reset role;
select is((select kind || ' by ' || by_user from public.stock_actions where id = current_setting('test.confirm')::uuid),
  'invoice_confirm by 00000000-0000-4000-8000-000000131001', 'Confirm & receive is one engine action, the admin''s');
select is(pg_temp.qty('21'), 304::numeric, 'Septocaine increases by 250: 5 boxes of 50 cartridges (the acceptance criterion)');
select is((select qty from public.batches where product_id = pg_temp.p('21') and lot = 'B441' and expiry_month = '2028-03-01'),
  250::numeric, 'on a batch with the line''s lot and expiry month');
select is(pg_temp.qty('23'), 1::numeric, 'Tempbond NE, created on its line, holds its 1 pack');
select is((select count(*)::integer from public.batches where product_id = pg_temp.p('23') and expiry_month is null and lot is null and qty = 1),
  1, 'undated, so it is listed under Missing expiry');
select is(pg_temp.qty('22'), 5::numeric, 'Endo file kit takes its 4: a product without a pack is not converted');
select is(pg_temp.qty('26'), 28::numeric, 'a case of 10 boxes counts 10 each, and a line without a quantity adds nothing');
select results_eq(
  $$ select p.name, t.type::text, t.delta, t.ref_type::text, t.ref_label, t.ref_id
     from public.transactions t join public.products p on p.id = t.product_id
     where t.action_id = current_setting('test.confirm')::uuid order by t.delta, p.name $$,
  $$ values ('Tempbond NE', 'receiving', 1.00, 'invoice', 'Invoice INV-10092', '00000000-0000-4000-8000-000000131031'::uuid),
            ('Endo file kit #15-40', 'receiving', 4.00, 'invoice', 'Invoice INV-10092', '00000000-0000-4000-8000-000000131031'::uuid),
            ('Rubber dam latex-free', 'receiving', 5.00, 'invoice', 'Invoice INV-10092', '00000000-0000-4000-8000-000000131031'::uuid),
            ('Nitrile gloves M', 'receiving', 20.00, 'invoice', 'Invoice INV-10092', '00000000-0000-4000-8000-000000131031'::uuid),
            ('Septocaine 4% 1:100,000', 'receiving', 250.00, 'invoice', 'Invoice INV-10092', '00000000-0000-4000-8000-000000131031'::uuid) $$,
  'one receiving row in the ledger per line received, referenced by the invoice; the surcharge goes into no stock');
select is(pg_temp.products(),
  'Endo file kit #15-40: 5.00 at 45.0000 from Patterson; Nitrile gloves M: 28.00 at 9.5000 from Patterson; '
  || 'Rubber dam latex-free: 5.00 at 1.1000 from Henry Schein; Septocaine 4% 1:100,000: 304.00 at 0.9960 from Henry Schein; '
  || 'Tempbond NE: 1.00 at 26.4000 from Patterson',
  'each cost is per counted unit ($49.80 a box is $0.996 a cartridge), and an empty supplier takes the invoice''s');
select is(pg_temp.to_buy(),
  'Endo file kit #15-40 received 4.00 received on its invoice; Rubber dam latex-free received 36.00 received on its invoice; '
  || 'Rubber dam latex-free to_buy 31.00',
  'Endo file kit moves from Ordered to Received, Rubber dam from To buy too, and Rubber dam, still low, is to buy again');
select is((select ordered_at = now() - interval '1 day' from public.to_buy_items where id = '00000000-0000-4000-8000-000000131041'),
  true, 'an ordered line keeps the day it was ordered');
select is(pg_temp.aliases(),
  'patterson "endo file kit 15 40 21mm" Endo file kit #15-40; patterson "nitrile gloves m 10 cs" Nitrile gloves M; '
  || 'patterson "nitrile gloves m backorder" Nitrile gloves M; patterson "rubber dam latex free" Rubber dam latex-free; '
  || 'patterson "septo 4 1 100k 50 bx" Septocaine 4% 1:100,000; patterson "tempbond ne 1pk" Tempbond NE',
  'every Matched or Created line teaches the supplier''s words, one pointing elsewhere is corrected, and the fee teaches none');
select is((select status::text || ' by ' || confirmed_by || case when confirm_action_id = current_setting('test.confirm')::uuid then ' as its action' else '' end
    from public.invoices where id = '00000000-0000-4000-8000-000000131031'),
  'confirmed by 00000000-0000-4000-8000-000000131001 as its action', 'the invoice is confirmed');
select is((select count(*)::integer from public.alerts where invoice_id = '00000000-0000-4000-8000-000000131031' and resolved_at is null),
  0, 'and its delivery alert closes');
select pg_temp.act_as('00000000-0000-4000-8000-000000131001');
select is((select format('%s · %s · %s', d ->> 'status', d ->> 'confirmed_by_name', ((d ->> 'confirmed_at') is not null)::text)
    from (select public.invoice_detail('00000000-0000-4000-8000-000000131031') d) x),
  'confirmed · Sarah Mitchell · true', 'invoice_detail says when it was received and by whom, for the read-only screen');

-- A received invoice stays as it is -------------------------------------------------------------------------------------
select results_eq(
  $$ select subject, invoice_id from public.activity_history('00000000-0000-4000-8000-000000131011', 'receiving')
     order by subject $$,
  $$ values ('Endo file kit #15-40', '00000000-0000-4000-8000-000000131031'::uuid),
            ('Nitrile gloves M', '00000000-0000-4000-8000-000000131031'::uuid),
            ('Rubber dam latex-free', '00000000-0000-4000-8000-000000131031'::uuid),
            ('Septocaine 4% 1:100,000', '00000000-0000-4000-8000-000000131031'::uuid),
            ('Tempbond NE', '00000000-0000-4000-8000-000000131031'::uuid) $$,
  'Activity''s History names the invoice each receipt came from, for the admin to open it read-only');
select is(public.invoice_confirm('00000000-0000-4000-8000-000000131031', pg_temp.k('10')), current_setting('test.confirm')::uuid,
  'the same key answers the first action');
select throws_ok($$ select public.invoice_confirm('00000000-0000-4000-8000-000000131031', pg_temp.k('11')) $$,
  '22023', 'This delivery was already received', 'a received invoice is not received twice');
select throws_ok($$ select public.invoice_line_reopen('00000000-0000-4000-8000-000000131052') $$,
  '22023', 'This invoice is no longer waiting for review.', 'its lines change no more');
select throws_ok($$ select public.invoice_discard('00000000-0000-4000-8000-000000131031') $$,
  '22023', 'This delivery was already received', 'it is not discarded, on this device or another');
-- As the Storage API deletes and replaces: the policies decide.
select set_config('storage.allow_delete_query', 'true', true);
delete from storage.objects where bucket_id = 'invoices' and name in (
  '00000000-0000-4000-8000-000000131011/00000000-0000-4000-8000-000000131031/page-1.jpg',
  '00000000-0000-4000-8000-000000131011/00000000-0000-4000-8000-000000131032/page-1.jpg');
select set_config('storage.allow_delete_query', 'false', true);
update storage.objects set name = '00000000-0000-4000-8000-000000131011/00000000-0000-4000-8000-000000131031/page-2.jpg'
where bucket_id = 'invoices' and name = '00000000-0000-4000-8000-000000131011/00000000-0000-4000-8000-000000131031/page-1.jpg';
reset role;
select results_eq(
  $$ select name from storage.objects where bucket_id = 'invoices' and name like '00000000-0000-4000-8000-000000131011/%' $$,
  $$ values ('00000000-0000-4000-8000-000000131011/00000000-0000-4000-8000-000000131031/page-1.jpg') $$,
  'its photo stays, neither deleted nor replaced, while an invoice still waiting for review loses its own');
select is(pg_temp.qty('21'), 304::numeric, 'and nothing was received twice');

-- The next delivery from the same supplier with the same words is matched at once ---------------------------------------
select is(public.invoice_reading_finish('00000000-0000-4000-8000-000000131035', jsonb_build_object('supplier', 'Patterson', 'lines', jsonb_build_array(
    jsonb_build_object('raw', 'ENDO FILE KIT 15-40 21MM', 'qty', 2, 'unit', 'boxes', 'kind', 'product'),
    jsonb_build_object('raw', 'TEMPBOND NE 1PK', 'qty', 1, 'unit', 'pack', 'kind', 'product')))) ->> 'status',
  'ready', 'Patterson''s next invoice is read');
select results_eq(
  $$ select n, state::text, product_id from public.invoice_lines where invoice_id = '00000000-0000-4000-8000-000000131035' order by n $$,
  $$ values (1, 'matched', '00000000-0000-4000-8000-000000131022'::uuid), (2, 'matched', '00000000-0000-4000-8000-000000131023'::uuid) $$,
  'with the same words, both lines are Matched: the endo kit that was a Possible match, and the product created (the acceptance criterion)');

-- Undo --------------------------------------------------------------------------------------------------------------------
-- A delivery partly used within its 10 seconds stays received: its dated batch would go below zero.
savepoint used;
select pg_temp.act_as('00000000-0000-4000-8000-000000131001');
select lives_ok($$ select public.stock_adjust(pg_temp.p('21'), 10, 'Physical count', null, pg_temp.k('30')) $$,
  'a count takes Septocaine down to 10 within the 10 seconds, into the cartridges just received');
select throws_ok($$ select public.undo_action(current_setting('test.confirm')::uuid, pg_temp.k('31')) $$,
  '22023', 'Some of this delivery was used already, so it stays received.', 'so Undo refuses rather than take back part of it');
reset role;
rollback to savepoint used;

select pg_temp.act_as('00000000-0000-4000-8000-000000131005');
select throws_ok($$ select public.undo_action(current_setting('test.confirm')::uuid, pg_temp.k('20')) $$,
  '42501', 'only the person who did it can undo it', 'another admin does not undo Sarah''s delivery (MS-100 D10)');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000131001');
select set_config('test.undo', public.undo_action(current_setting('test.confirm')::uuid, pg_temp.k('21'))::text, true);
reset role;
select is(pg_temp.products(), (select products from before_confirm),
  'Undo restores every quantity (the acceptance criterion), every cost and every supplier');
select is((select format('%s rows · %s · %s', count(*), sum(delta), min(ref_label)) from public.transactions
    where action_id = current_setting('test.undo')::uuid and ref_type = 'undo' and ref_id = current_setting('test.confirm')::uuid),
  '5 rows · -280.00 · Undo · Invoice INV-10092', 'as reversal rows in the ledger, which keeps the delivery');
select is((select count(*)::integer from public.activity_history('00000000-0000-4000-8000-000000131011', 'receiving')
    where ref_type = 'undo' and invoice_id is null), 5,
  'History lists the reversals too, which open no invoice');
select is(pg_temp.to_buy(), (select to_buy from before_confirm),
  'the To buy lines are back as they were, and the one the delivery opened again is gone');
select is((select bool_or(to_buy_dismissed) from public.products where id in (pg_temp.p('22'), pg_temp.p('24'))), false,
  'without counting as a suggestion someone removed');
select is(pg_temp.aliases(), (select aliases from before_confirm),
  'the words it taught are forgotten, and the corrected one points where it did before');
select is((select format('%s · %s · %s', status, (confirmed_at is null and confirmed_by is null)::text,
    (confirm_action_id is null and confirm_undo is null)::text)
    from public.invoices where id = '00000000-0000-4000-8000-000000131031'),
  'ready · true · true', 'the invoice waits for review again');
select is((select count(*)::integer from public.alerts where invoice_id = '00000000-0000-4000-8000-000000131031' and resolved_at is null),
  1, 'with its delivery alert open');
select pg_temp.act_as('00000000-0000-4000-8000-000000131001');
select is(public.undo_action(current_setting('test.confirm')::uuid, pg_temp.k('21')), current_setting('test.undo')::uuid,
  'the same Undo sent again answers the first');
select throws_ok($$ select public.undo_action(current_setting('test.confirm')::uuid, pg_temp.k('22')) $$,
  '22023', 'already undone', 'a second Undo is refused');
select is(public.invoice_confirm('00000000-0000-4000-8000-000000131031', pg_temp.k('10')), current_setting('test.confirm')::uuid,
  'the confirmation sent again answers its first action');
select is(pg_temp.qty('21'), 54::numeric, 'and receives nothing');

-- Received again, then past the Undo window -------------------------------------------------------------------------------
select set_config('test.again', public.invoice_confirm('00000000-0000-4000-8000-000000131031', pg_temp.k('12'))::text, true);
select is(pg_temp.qty('21'), 304::numeric, 'an invoice back in review is received again with a new key');
reset role;
update public.stock_actions set created_at = now() - interval '11 seconds' where id = current_setting('test.again')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-000000131001');
select throws_ok($$ select public.undo_action(current_setting('test.again')::uuid, pg_temp.k('23')) $$,
  '22023', 'the undo window has passed', 'after 10 seconds the delivery stays (MS-100 D10)');

-- A delivery invoiced in another currency ----------------------------------------------------------------------------------
select lives_ok($$ select public.invoice_confirm('00000000-0000-4000-8000-000000131036', pg_temp.k('13')) $$,
  'Benco''s invoice in US dollars is received');
reset role;
select is((select format('%s at %s', s.quantity, p.last_unit_cost) from public.products p join public.product_stock s on s.product_id = p.id
    where p.id = pg_temp.p('26')),
  '29.00 at 9.5000', 'its box is added, and the clinic''s cost in its own currency stays');

-- Counted units --------------------------------------------------------------------------------------------------------------
select results_eq(
  $$ select engine.invoice_counted_per_unit(u, c, s) from (values
       (1, 'boxes', 'cartridges', 50), (2, 'Cartridges', 'cartridges', 50), (3, 'carts', 'cartridges', 50),
       (4, 'CS', 'boxes', 10), (5, 'BX', 'boxes', 10), (6, 'EA', 'cartridges', 50), (7, null, 'cartridges', 50),
       (8, 'boxes', 'kits', null), (9, 'each', 'units', 100), (10, 'PCS', 'units', 100)) x (n, u, c, s) order by n $$,
  $$ values (50), (1), (1), (10), (1), (50), (50), (1), (1), (1) $$,
  'boxes of a 50-pack count 50 and the counted unit by any spelling 1; "EA" or no unit on a pack counts the pack; no pack, 1');

-- Pages set aside before they became an invoice ------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000131001');
select is(public.invoice_discard('00000000-0000-4000-8000-000000131098'), null::jsonb,
  'an invoice that was never created answers nothing to discard, so the app deletes its pages');
reset role;

select * from finish();
rollback;
