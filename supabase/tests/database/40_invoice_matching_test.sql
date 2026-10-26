-- MS-129 · Matching invoice lines (PRD §9, flow step 4: deterministic, no AI) against the demo catalog of
-- supabase/seed-demo.sql, with the five fixture invoices as extract_invoice hands them over: each recorded answer in
-- supabase/functions/extract_invoice/fixtures, tidied by reading.ts (reading_test.ts checks that the blocks below are
-- exactly that). The ticket's acceptance criterion: SEPTO 4% 1:100K 50/BX → Matched Septocaine, ENDO FILE KIT 15-40
-- 21MM → Possible match, TEMPBOND NE 1PK → New product, HANDLING / FUEL SURCHARGE → Needs review.
begin;
select plan(27);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000129001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone) values
  ('00000000-0000-4000-8000-000000129011', 'Catalog Dental', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-000000129013', 'Other Dental', 'CA', 'CAD', 'America/Toronto');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129001', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active');

-- The demo catalog (seed-demo.sql's 29 products), plus a deleted Tempbond NE here and a live one in another clinic:
-- neither is ever matched.
insert into public.products (clinic_id, name, unit, pack_unit, pack_size, tracking, archived_at)
select '00000000-0000-4000-8000-000000129011', name, unit, pack_unit, pack_size, tracking::public.tracking_mode, null
from (values
  ('Septocaine 4% 1:100,000', 'cartridges', 'box', 50, 'countable'), ('Endo file kit #15-40', 'kits', null, null, 'countable'),
  ('Composite A2', 'syringes', null, null, 'multi_use'), ('Bonding agent', 'bottles', null, null, 'multi_use'),
  ('Nitrile gloves M', 'boxes', 'case', 10, 'countable'), ('Surface disinfectant', 'bottles', null, null, 'multi_use'),
  ('Rubber dam latex-free', 'sheets', null, null, 'countable'), ('Gutta percha F2', 'packs', null, null, 'countable'),
  ('Suction tips', 'bags', 'case', 4, 'countable'), ('Alginate impression', 'bags', null, null, 'multi_use'),
  ('Composite A3', 'syringes', null, null, 'multi_use'), ('Etch gel 37%', 'syringes', null, null, 'multi_use'),
  ('Topical anesthetic gel', 'jars', null, null, 'multi_use'), ('Fluoride varnish', 'tubes', null, null, 'multi_use'),
  ('Prophy paste jar', 'jars', null, null, 'multi_use'), ('Sodium hypochlorite', 'bottles', null, null, 'multi_use'),
  ('Root canal sealer', 'kits', null, null, 'multi_use'), ('Impression material PVS', 'cartridges', null, null, 'multi_use'),
  ('Temporary cement', 'kits', null, null, 'multi_use'), ('Hemostatic gel', 'syringes', null, null, 'multi_use'),
  ('Needle 27g short', 'needles', 'box', 100, 'countable'), ('Paper points', 'packs', null, null, 'countable'),
  ('Prophy angle', 'angles', 'box', 100, 'countable'), ('Patient bib', 'bibs', 'case', 500, 'countable'),
  ('Matrix band', 'bands', null, null, 'countable'), ('Microbrushes', 'brushes', 'box', 100, 'countable'),
  ('Retraction cord', 'packs', null, null, 'countable'), ('Gauze', 'packs', null, null, 'countable'),
  ('Suture', 'packs', null, null, 'countable')
) p (name, unit, pack_unit, pack_size, tracking);
insert into public.products (clinic_id, name, unit, archived_at) values
  ('00000000-0000-4000-8000-000000129011', 'Tempbond NE', 'packs', now() - interval '1 day'),
  ('00000000-0000-4000-8000-000000129013', 'Tempbond NE', 'packs', null);

create function pg_temp.product(p_name text) returns uuid language sql stable as $$
  select id from public.products where clinic_id = '00000000-0000-4000-8000-000000129011' and name = p_name and archived_at is null
$$;
-- One invoice's lines as matched: n, state, the product matched or suggested, and a new product's name and unit.
create function pg_temp.lines(p_invoice uuid)
returns table (n integer, state text, product text, suggested_name text, suggested_unit text)
language sql stable as $$
  select l.n, l.state::text, p.name, l.suggested_name, l.suggested_unit
  from public.invoice_lines l left join public.products p on p.id = coalesce(l.product_id, l.suggested_product_id)
  where l.invoice_id = p_invoice order by l.n
$$;
create function pg_temp.reading(p_id uuid, p_supplier_folder text) returns void language sql as $$
  insert into public.invoices (id, clinic_id, storage_path, source, status, created_by, file_kind, file_count)
  values (p_id, '00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129011/' || p_supplier_folder,
          'file', 'reading', '00000000-0000-4000-8000-000000129001', 'pdf', 1)
$$;
create function pg_temp.stock() returns text language sql as $$
  select format('%s batches, %s ledger rows, %s To buy lines',
    (select count(*) from public.batches where clinic_id = '00000000-0000-4000-8000-000000129011'),
    (select count(*) from public.transactions where clinic_id = '00000000-0000-4000-8000-000000129011'),
    (select count(*) from public.to_buy_items where clinic_id = '00000000-0000-4000-8000-000000129011'))
$$;
create temp table stock_before as select pg_temp.stock() as stock;

-- The words matching compares --------------------------------------------------------------------------------------
select is(engine.invoice_alias_key('SEPTO 4% 1:100K 50/BX'), 'septo 4 1 100k 50 bx', 'an alias is kept under the line''s words');
select is(engine.invoice_alias_key('  Pâte  prophylactique, MENTHE '), 'pate prophylactique menthe', 'without case, accents or punctuation');
select is(engine.invoice_match_text('SEPTOCAINE 4% 1:100,000 CARTRIDGES 50/BX'), engine.invoice_match_text('Septocaine 4% 1:100,000'),
  'a line and a product name compare without the pack count and the unit');
select is(engine.invoice_match_text('SEPTO 4% 1:100K 50/BX'), 'septo 4 1 100000', 'thousands are written out (100K, 1:100,000)');
select is(engine.invoice_match_text('TEMPBOND NE 1PK'), 'tempbond ne', 'a pack count is no part of the name');
select is(engine.invoice_variant_numbers(engine.invoice_match_text('ENDO FILE KIT 15-40 21MM')), array['15', '21', '40'],
  'the numbers that tell variants apart: size, length');
select is(engine.invoice_variant_numbers(engine.invoice_match_text('Composite A2')), array['2'], 'and shade');

-- What the clinic learned when it confirmed Northbridge's previous delivery (MS-131): its words for Septocaine.
insert into public.supplier_aliases (clinic_id, supplier, raw_text_normalized, product_id) values
  ('00000000-0000-4000-8000-000000129011', engine.invoice_alias_key('Northbridge Dental Supply'),
   engine.invoice_alias_key('SEPTO 4% 1:100K 50/BX'), pg_temp.product('Septocaine 4% 1:100,000'));

select pg_temp.reading('00000000-0000-4000-8000-000000129061', 'northbridge');
select pg_temp.reading('00000000-0000-4000-8000-000000129062', 'lakeshore');
select pg_temp.reading('00000000-0000-4000-8000-000000129063', 'harbourview');
select pg_temp.reading('00000000-0000-4000-8000-000000129064', 'prairie');
select pg_temp.reading('00000000-0000-4000-8000-000000129065', 'rive-sud');

-- fixture: northbridge-inv-10092
select public.invoice_reading_finish('00000000-0000-4000-8000-000000129061', $fixture$
{"supplier": "Northbridge Dental Supply", "invoice_number": "INV-10092", "invoice_date": "2026-09-30", "currency": "CAD", "total": 520.03, "lines": [
  {"raw": "SEPTO 4% 1:100K 50/BX", "qty": 5, "unit": "box", "unit_price": 49.8, "line_total": 249, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "ENDO FILE KIT 15-40 21MM", "qty": 4, "unit": "box", "unit_price": 45, "line_total": 180, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "TEMPBOND NE 1PK", "qty": 1, "unit": "pack", "unit_price": 26.4, "line_total": 26.4, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "HANDLING / FUEL SURCHARGE", "qty": 1, "unit": "each", "unit_price": 4.8, "line_total": 4.8, "lot": null, "expiry": null, "kind": "fee"}]}
$fixture$::jsonb);
-- fixture: lakeshore-ls-58113
select public.invoice_reading_finish('00000000-0000-4000-8000-000000129062', $fixture$
{"supplier": "Lakeshore Dental Distributors", "invoice_number": "LS-58113", "invoice_date": "2026-10-14", "currency": "CAD", "total": 113.85, "lines": [
  {"raw": "NEEDLE 27G SHORT 100/BX", "qty": 2, "unit": "box", "unit_price": 18.5, "line_total": 37, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "PROPHY ANGLE DISPOSABLE 100/BX", "qty": 1, "unit": "box", "unit_price": 32, "line_total": 32, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "GAUZE SPONGES 2X2 8-PLY 200/PK", "qty": 5, "unit": "pack", "unit_price": 3.95, "line_total": 19.75, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "SHIPPING", "qty": 1, "unit": null, "unit_price": 12, "line_total": 12, "lot": null, "expiry": null, "kind": "fee"}]}
$fixture$::jsonb);
-- fixture: harbourview-hv-2207
select public.invoice_reading_finish('00000000-0000-4000-8000-000000129063', $fixture$
{"supplier": "Harbourview Dental Co.", "invoice_number": "HV-2207", "invoice_date": "2026-10-02", "currency": "CAD", "total": 744.5, "lines": [
  {"raw": "SEPTOCAINE 4% 1:100,000 CARTRIDGES 50/BX", "qty": 2, "unit": "box", "unit_price": 52.4, "line_total": 104.8, "lot": "B552", "expiry": "2028-03-01", "kind": "product"},
  {"raw": "COMPOSITE A2 SYRINGE 4G", "qty": 3, "unit": "each", "unit_price": 38.9, "line_total": 116.7, "lot": "7731A", "expiry": "2027-11-01", "kind": "product"},
  {"raw": "ETCH GEL 37% 3ML SYRINGE 2PK", "qty": 2, "unit": "pack", "unit_price": 14.25, "line_total": 28.5, "lot": "EG2210", "expiry": "2027-06-01", "kind": "product"},
  {"raw": "PAPER POINTS #30 120/BX", "qty": 2, "unit": "box", "unit_price": 9.8, "line_total": 19.6, "lot": "PP3091", "expiry": null, "kind": "product"},
  {"raw": "RETRACTION CORD #1 KNITTED", "qty": 1, "unit": "each", "unit_price": 21.4, "line_total": 21.4, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "MATRIX BANDS UNIVERSAL 144/PK", "qty": 1, "unit": "pack", "unit_price": 17.6, "line_total": 17.6, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "GUTTA PERCHA POINTS F2 60/BX", "qty": 3, "unit": "box", "unit_price": 11.2, "line_total": 33.6, "lot": "GP552", "expiry": "2029-09-01", "kind": "product"},
  {"raw": "NITRILE GLOVES MEDIUM 100/BX", "qty": 10, "unit": "box", "unit_price": 8.95, "line_total": 89.5, "lot": "N0915", "expiry": "2030-08-01", "kind": "product"},
  {"raw": "HEMOSTATIC GEL 1.2ML SYRINGE", "qty": 4, "unit": "each", "unit_price": 12.4, "line_total": 49.6, "lot": "HG118", "expiry": "2028-01-01", "kind": "product"},
  {"raw": "BONDING AGENT 5ML", "qty": 1, "unit": "bottle", "unit_price": 64, "line_total": 64, "lot": "BA9012", "expiry": "2027-12-01", "kind": "product"},
  {"raw": "COTTON ROLLS #2 MEDIUM 2000/BX", "qty": 1, "unit": "box", "unit_price": 15.9, "line_total": 15.9, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "ARTICULATING PAPER 40 MICRON 144/BX", "qty": 1, "unit": "box", "unit_price": 11.75, "line_total": 11.75, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "SALIVA EJECTORS CLEAR 100/BG", "qty": 3, "unit": "bag", "unit_price": 6.4, "line_total": 19.2, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "ALGINATE IMPRESSION MATERIAL 1LB", "qty": 2, "unit": "bag", "unit_price": 18.3, "line_total": 36.6, "lot": "AL7710", "expiry": "2028-02-01", "kind": "product"},
  {"raw": "SURFACE DISINFECTANT SPRAY 24OZ", "qty": 2, "unit": "each", "unit_price": 13.8, "line_total": 27.6, "lot": "SD4471", "expiry": "2028-10-01", "kind": "product"},
  {"raw": "ENVIRONMENTAL FEE", "qty": 1, "unit": "each", "unit_price": 2.5, "line_total": 2.5, "lot": null, "expiry": null, "kind": "fee"}]}
$fixture$::jsonb);
-- fixture: prairie-pdw-90412
select public.invoice_reading_finish('00000000-0000-4000-8000-000000129064', $fixture$
{"supplier": "Prairie Dental Wholesale", "invoice_number": "PDW-90412", "invoice_date": "2026-10-20", "currency": "USD", "total": 384.75, "lines": [
  {"raw": "FLUORIDE VARNISH 5% 50/BX", "qty": 2, "unit": "box", "unit_price": 42, "line_total": 84, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "TOPICAL ANESTHETIC GEL 20% BENZOCAINE 1OZ", "qty": 3, "unit": "jar", "unit_price": 6.75, "line_total": 20.25, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "ROOT CANAL SEALER KIT", "qty": 1, "unit": "kit", "unit_price": 96.5, "line_total": 96.5, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "PROPHY PASTE MINT MEDIUM 200/BX", "qty": 2, "unit": "box", "unit_price": 24.8, "line_total": 49.6, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "MICROBRUSH FINE 100/BX", "qty": 3, "unit": "box", "unit_price": 7.2, "line_total": 21.6, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "PATIENT BIBS 2-PLY 500/CS", "qty": 1, "unit": "case", "unit_price": 39, "line_total": 39, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "SUCTION TIPS HVE VENTED 100/BG", "qty": 2, "unit": "bag", "unit_price": 11.4, "line_total": 22.8, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "TEMPORARY CEMENT NON-EUGENOL KIT", "qty": 1, "unit": "kit", "unit_price": 33, "line_total": 33, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "FREIGHT", "qty": 1, "unit": null, "unit_price": 18, "line_total": 18, "lot": null, "expiry": null, "kind": "fee"}]}
$fixture$::jsonb);
-- fixture: rive-sud-f-3381
select public.invoice_reading_finish('00000000-0000-4000-8000-000000129065', $fixture$
{"supplier": "Fournitures dentaires Rive-Sud", "invoice_number": "F-3381", "invoice_date": "2026-10-09", "currency": "CAD", "total": 100.31, "lines": [
  {"raw": "Gants nitrile moyens 100/bte", "qty": 4, "unit": "box", "unit_price": 9.25, "line_total": 37, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "Pâte prophylactique menthe 200 g", "qty": 2, "unit": "jar", "unit_price": 16.4, "line_total": 32.8, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "Hypochlorite de sodium 5,25 % 1 L", "qty": 1, "unit": "bottle", "unit_price": 7.95, "line_total": 7.95, "lot": null, "expiry": null, "kind": "product"},
  {"raw": "Frais de livraison", "qty": 1, "unit": null, "unit_price": 9.5, "line_total": 9.5, "lot": null, "expiry": null, "kind": "fee"}]}
$fixture$::jsonb);

-- What each invoice says --------------------------------------------------------------------------------------------
select results_eq(
  $$ select number, supplier, invoice_date, currency::text, total, status::text,
            (select count(*)::integer from public.invoice_lines l where l.invoice_id = i.id)
     from public.invoices i where i.clinic_id = '00000000-0000-4000-8000-000000129011' order by i.id $$,
  $$ values ('INV-10092', 'Northbridge Dental Supply', '2026-09-30'::date, 'CAD', 520.03::numeric, 'ready', 4),
            ('LS-58113', 'Lakeshore Dental Distributors', '2026-10-14'::date, 'CAD', 113.85::numeric, 'ready', 4),
            ('HV-2207', 'Harbourview Dental Co.', '2026-10-02'::date, 'CAD', 744.50::numeric, 'ready', 16),
            ('PDW-90412', 'Prairie Dental Wholesale', '2026-10-20'::date, 'USD', 384.75::numeric, 'ready', 9),
            ('F-3381', 'Fournitures dentaires Rive-Sud', '2026-10-09'::date, 'CAD', 100.31::numeric, 'ready', 4) $$,
  'the five invoices are ready with their supplier, number, date, currency, total and every line');

-- Northbridge: the ticket's acceptance criterion ------------------------------------------------------------------------
select results_eq($$ select * from pg_temp.lines('00000000-0000-4000-8000-000000129061') $$,
  $$ values (1, 'matched', 'Septocaine 4% 1:100,000', null, null),
            (2, 'possible_match', 'Endo file kit #15-40', null, null),
            (3, 'new_product', null, 'Tempbond NE', 'packs'),
            (4, 'needs_review', null, null, null) $$,
  'SEPTO 4% 1:100K 50/BX is Matched to Septocaine through the supplier''s words; ENDO FILE KIT 15-40 21MM, a length the product does not name, a Possible match; TEMPBOND NE 1PK a New product with a name and unit suggested; HANDLING / FUEL SURCHARGE Needs review');
select is((select array_agg(read_state::text order by n) from public.invoice_lines where invoice_id = '00000000-0000-4000-8000-000000129061'),
  array['matched', 'possible_match', 'new_product', 'needs_review'], 'each line keeps the state it was read in');
select ok((select match_score between 0.45 and 0.75 from public.invoice_lines where invoice_id = '00000000-0000-4000-8000-000000129061' and n = 2)
  and (select match_score < 0.45 from public.invoice_lines where invoice_id = '00000000-0000-4000-8000-000000129061' and n = 3),
  'the scores kept show why: a similar name, and nothing close');
select is((select kind from public.invoice_lines where invoice_id = '00000000-0000-4000-8000-000000129061' and n = 4), 'fee',
  'the surcharge is a fee as read');

-- Lakeshore: a photographed invoice -------------------------------------------------------------------------------------
select results_eq($$ select * from pg_temp.lines('00000000-0000-4000-8000-000000129062') $$,
  $$ values (1, 'matched', 'Needle 27g short', null, null),
            (2, 'possible_match', 'Prophy angle', null, null),
            (3, 'new_product', null, 'Gauze sponges 2X2 8-PLY', 'packs'),
            (4, 'needs_review', null, null, null) $$,
  'NEEDLE 27G SHORT 100/BX is the clinic''s Needle 27g short; a longer description is a Possible match; gauze sponges are new; shipping needs review');

-- Harbourview: two pages, lots and expiry months ------------------------------------------------------------------------
select results_eq($$ select * from pg_temp.lines('00000000-0000-4000-8000-000000129063') $$,
  $$ values (1, 'matched', 'Septocaine 4% 1:100,000', null, null),
            (2, 'possible_match', 'Composite A2', null, null),
            (3, 'possible_match', 'Etch gel 37%', null, null),
            (4, 'possible_match', 'Paper points', null, null),
            (5, 'possible_match', 'Retraction cord', null, null),
            (6, 'possible_match', 'Matrix band', null, null),
            (7, 'possible_match', 'Gutta percha F2', null, null),
            (8, 'possible_match', 'Nitrile gloves M', null, null),
            (9, 'possible_match', 'Hemostatic gel', null, null),
            (10, 'possible_match', 'Bonding agent', null, null),
            (11, 'new_product', null, 'Cotton rolls #2 medium', 'boxes'),
            (12, 'new_product', null, 'Articulating paper 40 micron', 'boxes'),
            (13, 'new_product', null, 'Saliva ejectors clear', 'bags'),
            (14, 'possible_match', 'Alginate impression', null, null),
            (15, 'possible_match', 'Surface disinfectant', null, null),
            (16, 'needs_review', null, null, null) $$,
  'the full Septocaine name is Matched by similarity; names with a size, weight or extra words are Possible matches; three products are new; the environmental fee needs review');
select ok((select match_score >= 0.75 from public.invoice_lines where invoice_id = '00000000-0000-4000-8000-000000129063' and n = 2),
  'COMPOSITE A2 SYRINGE 4G is as close as a match, but 4 g is a size the product does not name: never applied automatically');
select results_eq(
  $$ select lot, expiry_month from public.invoice_lines where invoice_id = '00000000-0000-4000-8000-000000129063' and n in (1, 4, 5) order by n $$,
  $$ values ('B552', '2028-03-01'::date), ('PP3091', null::date), (null, null::date) $$,
  'a line keeps the lot and expiry month it was printed with, and none when there were none');

-- Prairie: two scanned pages from a US supplier -------------------------------------------------------------------------
select results_eq($$ select * from pg_temp.lines('00000000-0000-4000-8000-000000129064') $$,
  $$ values (1, 'possible_match', 'Fluoride varnish', null, null),
            (2, 'possible_match', 'Topical anesthetic gel', null, null),
            (3, 'matched', 'Root canal sealer', null, null),
            (4, 'possible_match', 'Prophy paste jar', null, null),
            (5, 'possible_match', 'Microbrushes', null, null),
            (6, 'possible_match', 'Patient bib', null, null),
            (7, 'possible_match', 'Suction tips', null, null),
            (8, 'possible_match', 'Temporary cement', null, null),
            (9, 'needs_review', null, null, null) $$,
  'ROOT CANAL SEALER KIT is the clinic''s Root canal sealer; the rest are Possible matches and the freight needs review');

-- Rive-Sud: in French ---------------------------------------------------------------------------------------------------
select results_eq($$ select * from pg_temp.lines('00000000-0000-4000-8000-000000129065') $$,
  $$ values (1, 'new_product', null, 'Gants nitrile moyens', 'boxes'),
            (2, 'new_product', null, 'Pâte prophylactique menthe 200 g', 'jars'),
            (3, 'possible_match', 'Sodium hypochlorite', null, null),
            (4, 'needs_review', null, null, null) $$,
  'French names are new products, kept as written; Hypochlorite de sodium is a Possible match; Frais de livraison needs review');

-- The rules around the catalog -------------------------------------------------------------------------------------------
select is((select count(*)::integer from public.invoice_lines l join public.products p on p.id = coalesce(l.product_id, l.suggested_product_id)
  where l.invoice_id in (select id from public.invoices where clinic_id = '00000000-0000-4000-8000-000000129011')
    and (p.archived_at is not null or p.clinic_id <> '00000000-0000-4000-8000-000000129011')), 0,
  'no line is matched to a deleted product or another clinic''s, though both have Tempbond NE');

-- The supplier read slightly differently: the alias's words still name one product.
select pg_temp.reading('00000000-0000-4000-8000-000000129066', 'northbridge-2');
select public.invoice_reading_finish('00000000-0000-4000-8000-000000129066',
  '{"supplier": "Northbridge Dental Supply Inc.", "lines": [{"raw": "SEPTO 4% 1:100K 50/BX", "qty": 2, "unit": "box", "kind": "product"}]}');
select results_eq($$ select n, state, product from pg_temp.lines('00000000-0000-4000-8000-000000129066') $$,
  $$ values (1, 'matched', 'Septocaine 4% 1:100,000') $$, 'the same words from the supplier named a little differently still match');

-- Two suppliers' identical words for two products: the words decide nothing.
insert into public.supplier_aliases (clinic_id, supplier, raw_text_normalized, product_id) values
  ('00000000-0000-4000-8000-000000129011', 'lakeshore dental distributors', engine.invoice_alias_key('SEPTO 4% 1:100K 50/BX'),
   pg_temp.product('Composite A2'));
select pg_temp.reading('00000000-0000-4000-8000-000000129067', 'unknown');
select public.invoice_reading_finish('00000000-0000-4000-8000-000000129067',
  '{"supplier": "Harbour Supply", "lines": [{"raw": "SEPTO 4% 1:100K 50/BX", "qty": 2, "unit": "box", "kind": "product"}]}');
select results_eq($$ select n, state, product from pg_temp.lines('00000000-0000-4000-8000-000000129067') $$,
  $$ values (1, 'possible_match', 'Septocaine 4% 1:100,000') $$,
  'when other suppliers'' identical words name different products, the line falls back to similarity');
select pg_temp.reading('00000000-0000-4000-8000-000000129068', 'northbridge-3');
select public.invoice_reading_finish('00000000-0000-4000-8000-000000129068',
  '{"supplier": "Northbridge Dental Supply", "lines": [{"raw": "SEPTO 4% 1:100K 50/BX", "qty": 2, "unit": "box", "kind": "product"}]}');
select results_eq($$ select n, state, product from pg_temp.lines('00000000-0000-4000-8000-000000129068') $$,
  $$ values (1, 'matched', 'Septocaine 4% 1:100,000') $$, 'while the supplier''s own words still match');

-- Without the supplier's words, SEPTO is only a Possible match: an abbreviation is never applied automatically.
update public.products set archived_at = now() where id = pg_temp.product('Composite A2');
delete from public.supplier_aliases where clinic_id = '00000000-0000-4000-8000-000000129011' and supplier = 'northbridge dental supply';
select pg_temp.reading('00000000-0000-4000-8000-000000129069', 'northbridge-4');
select public.invoice_reading_finish('00000000-0000-4000-8000-000000129069',
  '{"supplier": "Northbridge Dental Supply", "lines": [{"raw": "SEPTO 4% 1:100K 50/BX", "qty": 2, "unit": "box", "kind": "product"}]}');
select results_eq($$ select n, state, product from pg_temp.lines('00000000-0000-4000-8000-000000129069') $$,
  $$ values (1, 'possible_match', 'Septocaine 4% 1:100,000') $$,
  'with no alias, and the other supplier''s alias naming a deleted product, SEPTO is a Possible match: "Is this Septocaine 4% 1:100,000?"');

-- A line the reader called a product but whose words are a fee, or a credit, still needs review.
select pg_temp.reading('00000000-0000-4000-8000-000000129070', 'fees');
select public.invoice_reading_finish('00000000-0000-4000-8000-000000129070', $json$ {"supplier": "Northbridge Dental Supply", "lines": [
  {"raw": "FUEL SURCHARGE", "qty": 1, "kind": "product"},
  {"raw": "RETURN - GAUZE", "qty": -2, "line_total": -7.9, "kind": "product"},
  {"raw": "Gauze", "qty": 2, "unit": "pack", "kind": "product"},
  {"raw": "1 BOX", "qty": 1, "unit": "box", "kind": "product"}]} $json$);
select results_eq($$ select * from pg_temp.lines('00000000-0000-4000-8000-000000129070') $$,
  $$ values (1, 'needs_review', null, null, null), (2, 'needs_review', null, null, null), (3, 'matched', 'Gauze', null, null),
            (4, 'new_product', null, '1 box', 'boxes') $$,
  'a surcharge or a return never becomes stock; an exact name is Matched; a line of pack words alone is new');

select is(pg_temp.stock(), (select stock from stock_before), 'matching moved no stock');
select ok(not exists (select 1 from public.invoice_lines l where l.invoice_id = '00000000-0000-4000-8000-000000129061' and l.state <> l.read_state),
  'nothing resolved a line yet');
select is((select count(*)::integer from public.alerts where kind = 'invoice_ready' and resolved_at is null
  and invoice_id in (select id from public.invoices where clinic_id = '00000000-0000-4000-8000-000000129011')), 10,
  'each invoice read waits for review in the bell');

select * from finish();
rollback;
