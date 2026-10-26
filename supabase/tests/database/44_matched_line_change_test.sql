-- MS-130 fix (Refs #101) · A matched invoice line can be changed to another product: the reading keeps the product each
-- line read as Matched was matched to; such a line takes the product picked on Which product is this? from its badge
-- and reopens to the product it was read as; a Possible match is pointed at a product other than its suggestion; the
-- state and the product a line was read as never change; the same refusals as every line choice; Confirm & receive
-- learns the supplier's words for the product chosen, not the one read, and its Undo points them back; and a line on a
-- product deleted since it was read takes another product instead of the invoice being discarded.
begin;
select plan(42);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000130501', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@change.test'),
  ('00000000-0000-4000-8000-000000130502', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@change.test'),
  ('00000000-0000-4000-8000-000000130503', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'olivia@change.test'),
  ('00000000-0000-4000-8000-000000130504', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dana@change.test');
insert into public.clinics (id, name, country, currency, time_zone, trial_ends_at) values
  ('00000000-0000-4000-8000-000000130511', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days'),
  ('00000000-0000-4000-8000-000000130512', 'Lapsed Dental', 'CA', 'CAD', 'America/Toronto', now() - interval '1 day'),
  ('00000000-0000-4000-8000-000000130513', 'Other Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000130511', '00000000-0000-4000-8000-000000130501', 'sarah@change.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000130511', '00000000-0000-4000-8000-000000130502', 'michael@change.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000130512', '00000000-0000-4000-8000-000000130503', 'olivia@change.test', 'Olivia Grant', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000130513', '00000000-0000-4000-8000-000000130504', 'dana@change.test', 'Dana Lee', 'admin', 'active');

-- Septocaine and two Articaines come in boxes of 50 cartridges; Gauze 2x2 was deleted; the last two are another
-- clinic's and the read-only clinic's.
insert into public.products (id, clinic_id, name, unit, pack_unit, pack_size, archived_at) values
  ('00000000-0000-4000-8000-000000130521', '00000000-0000-4000-8000-000000130511', 'Septocaine 4% 1:100,000', 'cartridges', 'box', 50, null),
  ('00000000-0000-4000-8000-000000130522', '00000000-0000-4000-8000-000000130511', 'Articaine 4% 1:100,000', 'cartridges', 'box', 50, null),
  ('00000000-0000-4000-8000-000000130523', '00000000-0000-4000-8000-000000130511', 'Articaine 4% 1:200,000', 'cartridges', 'box', 50, null),
  ('00000000-0000-4000-8000-000000130524', '00000000-0000-4000-8000-000000130511', 'Nitrile gloves M', 'boxes', null, null, null),
  ('00000000-0000-4000-8000-000000130525', '00000000-0000-4000-8000-000000130511', 'Nitrile gloves M powder-free', 'boxes', null, null, null),
  ('00000000-0000-4000-8000-000000130526', '00000000-0000-4000-8000-000000130511', 'Endo file kit #15-40', 'kits', null, null, null),
  ('00000000-0000-4000-8000-000000130527', '00000000-0000-4000-8000-000000130511', 'Rotary files ProTaper', 'kits', null, null, null),
  ('00000000-0000-4000-8000-000000130528', '00000000-0000-4000-8000-000000130511', 'Gauze 2x2', 'packs', null, null, now()),
  ('00000000-0000-4000-8000-000000130529', '00000000-0000-4000-8000-000000130511', 'Gauze 2x2 non-woven', 'packs', null, null, null),
  ('00000000-0000-4000-8000-000000130530', '00000000-0000-4000-8000-000000130513', 'Other gloves', 'boxes', null, null, null),
  ('00000000-0000-4000-8000-000000130531', '00000000-0000-4000-8000-000000130512', 'Lapsed gloves', 'boxes', null, null, null);
insert into public.batches (clinic_id, product_id, qty) values
  ('00000000-0000-4000-8000-000000130511', '00000000-0000-4000-8000-000000130521', 54);
-- Patterson's words for Septocaine, learned from an earlier delivery: the reading matches SEPTO to it at once.
insert into public.supplier_aliases (clinic_id, supplier, raw_text_normalized, product_id) values
  ('00000000-0000-4000-8000-000000130511', 'patterson', 'septo 4 1 100k 50 bx', '00000000-0000-4000-8000-000000130521');

-- 41: Patterson's delivery, being read; 42: Lapsed Dental's, read-only; 43: a line read as Matched to Gauze 2x2, which
-- was deleted since.
insert into public.invoices (id, clinic_id, storage_path, source, status, supplier, number, total, created_by, file_kind, file_count) values
  ('00000000-0000-4000-8000-000000130541', '00000000-0000-4000-8000-000000130511',
   '00000000-0000-4000-8000-000000130511/00000000-0000-4000-8000-000000130541', 'camera', 'reading', null, null, null,
   '00000000-0000-4000-8000-000000130501', 'jpg', 1),
  ('00000000-0000-4000-8000-000000130542', '00000000-0000-4000-8000-000000130512',
   '00000000-0000-4000-8000-000000130512/00000000-0000-4000-8000-000000130542', 'camera', 'ready', 'Patterson', 'INV-2', 10,
   '00000000-0000-4000-8000-000000130503', 'jpg', 1),
  ('00000000-0000-4000-8000-000000130543', '00000000-0000-4000-8000-000000130511',
   '00000000-0000-4000-8000-000000130511/00000000-0000-4000-8000-000000130543', 'camera', 'ready', 'Patterson', 'INV-3', 12,
   '00000000-0000-4000-8000-000000130501', 'jpg', 1);
insert into public.invoice_lines (id, clinic_id, invoice_id, n, raw, qty, unit, unit_price, line_total, kind, state, product_id) values
  ('00000000-0000-4000-8000-000000130561', '00000000-0000-4000-8000-000000130512', '00000000-0000-4000-8000-000000130542', 1,
   'LAPSED GLOVES', 1, 'box', 10, 10, 'product', 'matched', '00000000-0000-4000-8000-000000130531'),
  ('00000000-0000-4000-8000-000000130562', '00000000-0000-4000-8000-000000130511', '00000000-0000-4000-8000-000000130543', 1,
   'GAUZE 2X2', 3, 'packs', 4, 12, 'product', 'matched', '00000000-0000-4000-8000-000000130528');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
-- An idempotency key, and a product of this test, by their two last digits.
create function pg_temp.k(p_n text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000001309' || p_n)::uuid
$$;
create function pg_temp.p(p_n text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000001305' || p_n)::uuid
$$;
-- Patterson's invoice line n, as the reading below created it (kept in a setting, which every role reads).
create function pg_temp.l(p_n integer) returns uuid language sql as $$
  select current_setting('test.line' || p_n)::uuid
$$;
create function pg_temp.qty(p_product text) returns numeric language sql as $$
  select coalesce((select quantity from public.product_stock where product_id = pg_temp.p(p_product)), 0)
$$;
-- A line as the table keeps it: its state and product, the state and product it was read as, and its suggestion.
create function pg_temp.line(p_id uuid) returns text language sql as $$
  select format('%s %s (read %s %s)%s', l.state, coalesce(p.name, 'with no product'), l.read_state,
    coalesce(r.name, 'with no product'), coalesce(', suggests ' || s.name, ''))
  from public.invoice_lines l
  left join public.products p on p.id = l.product_id
  left join public.products r on r.id = l.read_product_id
  left join public.products s on s.id = l.suggested_product_id
  where l.id = p_id
$$;
create function pg_temp.aliases() returns text language sql as $$
  select string_agg(format('%s "%s" %s', a.supplier, a.raw_text_normalized, p.name), '; ' order by a.raw_text_normalized)
  from public.supplier_aliases a join public.products p on p.id = a.product_id
  where a.clinic_id = '00000000-0000-4000-8000-000000130511'
$$;
-- Stock as receiving changes it: choices on a line must leave it as it is.
create function pg_temp.stock() returns text language sql as $$
  select format('%s batches, %s units, %s ledger rows',
    (select count(*) from public.batches where clinic_id = '00000000-0000-4000-8000-000000130511'),
    (select coalesce(sum(qty), 0) from public.batches where clinic_id = '00000000-0000-4000-8000-000000130511'),
    (select count(*) from public.transactions where clinic_id = '00000000-0000-4000-8000-000000130511'))
$$;
create temp table stock_before as select pg_temp.stock() as stock;

select has_column('public', 'invoice_lines', 'read_product_id', 'each line keeps the product it was read as');
select ok(not has_function_privilege('anon', 'public.invoice_line_match(uuid, uuid)', 'execute')
  and not has_function_privilege('anon', 'public.invoice_line_reopen(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.invoice_line_match(uuid, uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.invoice_line_reopen(uuid)', 'execute'),
  'the two functions redefined keep their privileges: members only (admins, checked inside)');

-- The reading ----------------------------------------------------------------------------------------------------------
select is(public.invoice_reading_finish('00000000-0000-4000-8000-000000130541', jsonb_build_object(
    'supplier', 'Patterson', 'invoice_number', 'INV-500', 'currency', 'CAD', 'lines', jsonb_build_array(
      jsonb_build_object('raw', 'SEPTO 4% 1:100K 50/BX', 'qty', 5, 'unit', 'boxes', 'unit_price', 49.80, 'line_total', 249, 'kind', 'product'),
      jsonb_build_object('raw', 'NITRILE GLOVES M', 'qty', 2, 'unit', 'boxes', 'unit_price', 9.50, 'line_total', 19, 'kind', 'product'),
      jsonb_build_object('raw', 'ENDO FILE KIT 15-40 21MM', 'qty', 4, 'unit', 'boxes', 'unit_price', 45, 'line_total', 180, 'kind', 'product')
    ))) ->> 'status',
  'ready', 'Patterson''s delivery is read');
select set_config('test.line' || n, id::text, true) from public.invoice_lines
where invoice_id = '00000000-0000-4000-8000-000000130541';
select results_eq(
  $$ select pg_temp.line(pg_temp.l(n)) from generate_series(1, 3) n $$,
  $$ values ('matched Septocaine 4% 1:100,000 (read matched Septocaine 4% 1:100,000)'),
            ('matched Nitrile gloves M (read matched Nitrile gloves M)'),
            ('possible_match with no product (read possible_match with no product), suggests Endo file kit #15-40') $$,
  'a line read as Matched, through the supplier''s words or a near-identical name, keeps the product it was read as; any other none');
select pg_temp.act_as('00000000-0000-4000-8000-000000130501');
select is((select format('%s · %s', l ->> 'product_id', l ->> 'read_product_id')
    from (select public.invoice_detail('00000000-0000-4000-8000-000000130541') -> 'lines' -> 0 l) x),
  '00000000-0000-4000-8000-000000130521 · 00000000-0000-4000-8000-000000130521',
  'invoice_detail answers the product a line was read as, for the screen to tell what its badge does');
reset role;

-- Who changes a line read as Matched ---------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000130502');
select throws_ok($$ select public.invoice_line_match(pg_temp.l(1), pg_temp.p('22')) $$,
  '42501', 'Only an admin can receive deliveries', 'Staff change no line');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000130504');
select throws_ok($$ select public.invoice_line_match(pg_temp.l(1), pg_temp.p('22')) $$,
  '42501', 'Only an admin can receive deliveries', 'nor another clinic''s admin');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000130503');
select throws_ok($$ select public.invoice_line_match('00000000-0000-4000-8000-000000130561', '00000000-0000-4000-8000-000000130531') $$,
  '42501', 'The clinic is read-only until a payment method is added', 'and a read-only clinic changes none (MS-142)');
reset role;

-- What a line read as Matched may become ------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000130501');
select throws_ok($$ select public.invoice_line_match(pg_temp.l(1), pg_temp.p('28')) $$,
  '22023', 'This product was deleted.', 'a deleted product is no match');
select throws_ok($$ select public.invoice_line_match(pg_temp.l(1), pg_temp.p('30')) $$,
  '22023', 'Choose a product for this line.', 'nor another clinic''s');
select throws_ok($$ select public.invoice_line_match(pg_temp.l(1), null) $$,
  '22023', 'Choose a product for this line.', 'nor none');
select throws_ok($$ select public.invoice_line_create(pg_temp.l(1), pg_temp.p('22')) $$,
  '22023', 'This line is already resolved.', 'a line read as Matched is not Created as a new product');
select throws_ok($$ select public.invoice_line_skip(pg_temp.l(1)) $$,
  '22023', 'This line is already resolved.', 'nor ignored');
select is(pg_temp.line(pg_temp.l(1)), 'matched Septocaine 4% 1:100,000 (read matched Septocaine 4% 1:100,000)',
  'and a refusal leaves it as it was read');

-- The badge of a line read as Matched: Which product is this?, then back to the product read ------------------------------
select is((select format('%s · %s · read as %s', j ->> 'state', j ->> 'product_name', j ->> 'read_product_id')
    from (select public.invoice_line_match(pg_temp.l(1), pg_temp.p('23')) j) x),
  'matched · Articaine 4% 1:200,000 · read as 00000000-0000-4000-8000-000000130521',
  'the product picked replaces the one read, and the answer still names the product read');
select is(public.invoice_line_match(pg_temp.l(1), pg_temp.p('22')) ->> 'product_name', 'Articaine 4% 1:100,000',
  'a second pick replaces the first');
select is(pg_temp.line(pg_temp.l(1)), 'matched Articaine 4% 1:100,000 (read matched Septocaine 4% 1:100,000)',
  'the line keeps the state and the product it was read as');
select is(public.invoice_line_reopen(pg_temp.l(1)) ->> 'product_name', 'Septocaine 4% 1:100,000',
  'its badge then reopens it to the product it was read as');
select is(pg_temp.line(pg_temp.l(1)), 'matched Septocaine 4% 1:100,000 (read matched Septocaine 4% 1:100,000)',
  'Matched, as it was read');
select is(public.invoice_line_reopen(pg_temp.l(1)) ->> 'product_name', 'Septocaine 4% 1:100,000',
  'and reopening a line already as it was read changes nothing');

-- A Possible match whose suggestion is wrong ------------------------------------------------------------------------------
select is(public.invoice_line_match(pg_temp.l(3), pg_temp.p('27')) ->> 'state', 'matched',
  'a Possible match is pointed at a product other than its suggestion through Which product is this?');
select is(pg_temp.line(pg_temp.l(3)),
  'matched Rotary files ProTaper (read possible_match with no product), suggests Endo file kit #15-40',
  'Matched to the product picked, the suggestion kept');
select throws_ok($$ select public.invoice_line_match(pg_temp.l(3), pg_temp.p('26')) $$,
  '22023', 'This line is already resolved.', 'a line read in another state is changed only after its badge reopened it');
select is(public.invoice_line_reopen(pg_temp.l(3)) ->> 'state', 'possible_match', 'its badge reopens it');
select is(pg_temp.line(pg_temp.l(3)), 'possible_match with no product (read possible_match with no product), suggests Endo file kit #15-40',
  'a Possible match again, the product picked dropped');
reset role;

-- No update changes what a line was read as ----------------------------------------------------------------------------------
update public.invoice_lines set read_state = 'new_product', read_product_id = pg_temp.p('22') where id = pg_temp.l(1);
select is(pg_temp.line(pg_temp.l(1)), 'matched Septocaine 4% 1:100,000 (read matched Septocaine 4% 1:100,000)',
  'not even the table owner''s: MS-147''s figures read the state, and the badge the product');
select is(pg_temp.stock(), (select stock from stock_before), 'and no choice moved stock');

-- Confirm & receive learns the supplier's words for the product chosen ----------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000130501');
select lives_ok($$
  select public.invoice_line_match(pg_temp.l(n), pg_temp.p(p))
  from (values (1, '22'), (2, '25'), (3, '26')) v (n, p) order by n
$$, 'SEPTO is changed to Articaine, the gloves to the powder-free ones, and the endo kit matched as suggested');
select set_config('test.confirm', public.invoice_confirm('00000000-0000-4000-8000-000000130541', pg_temp.k('01'))::text, true);
reset role;
select is(array[pg_temp.qty('21'), pg_temp.qty('22'), pg_temp.qty('24'), pg_temp.qty('25')], array[54, 250, 0, 2]::numeric[],
  'the delivery goes into the products chosen, not the ones read: 5 boxes of Articaine are 250 cartridges, Septocaine keeps 54');
select is(pg_temp.aliases(),
  'patterson "endo file kit 15 40 21mm" Endo file kit #15-40; patterson "nitrile gloves m" Nitrile gloves M powder-free; '
  || 'patterson "septo 4 1 100k 50 bx" Articaine 4% 1:100,000',
  'the supplier''s words are learned for the products chosen, and the words that named the product read now name the one chosen');
select results_eq(
  $$ select l.n, l.read_state::text, l.read_product_id from public.invoice_lines l
     where l.invoice_id = '00000000-0000-4000-8000-000000130541' order by l.n $$,
  $$ values (1, 'matched', '00000000-0000-4000-8000-000000130521'::uuid), (2, 'matched', '00000000-0000-4000-8000-000000130524'::uuid),
            (3, 'possible_match', null::uuid) $$,
  'the lines keep the state and the product they were read as: MS-147 counts two read as Matched');

select pg_temp.act_as('00000000-0000-4000-8000-000000130501');
select lives_ok($$ select public.undo_action(current_setting('test.confirm')::uuid, pg_temp.k('02')) $$, 'Undo within 10 seconds');
reset role;
select is(pg_temp.aliases(), 'patterson "septo 4 1 100k 50 bx" Septocaine 4% 1:100,000',
  'puts the supplier''s words back: the ones learned are forgotten, and SEPTO names Septocaine again');
select is(array[pg_temp.qty('21'), pg_temp.qty('22'), pg_temp.qty('25')], array[54, 0, 0]::numeric[], 'and the stock');
select pg_temp.act_as('00000000-0000-4000-8000-000000130501');
select is(pg_temp.line(pg_temp.l(1)), 'matched Articaine 4% 1:100,000 (read matched Septocaine 4% 1:100,000)',
  'back in review, the line is still on the product chosen');

-- A received invoice's lines stay as they are ----------------------------------------------------------------------------
select lives_ok($$ select public.invoice_confirm('00000000-0000-4000-8000-000000130541', pg_temp.k('03')) $$,
  'the delivery is received again');
select throws_ok($$ select public.invoice_line_match(pg_temp.l(1), pg_temp.p('21')) $$,
  '22023', 'This invoice is no longer waiting for review.', 'after which a line read as Matched changes no more');
select throws_ok($$ select public.invoice_line_reopen(pg_temp.l(1)) $$,
  '22023', 'This invoice is no longer waiting for review.', 'nor reopens');

-- A product deleted since its line was read: another product instead of Discard invoice ------------------------------------
select throws_ok($$ select public.invoice_confirm('00000000-0000-4000-8000-000000130543', pg_temp.k('04')) $$,
  '22023', 'Gauze 2x2 was deleted. Choose another product for line 1.', 'Confirm & receive says which line needs another product');
select is(public.invoice_line_match('00000000-0000-4000-8000-000000130562', pg_temp.p('29')) ->> 'product_name', 'Gauze 2x2 non-woven',
  'which its badge now offers: the line read as Matched to the deleted product takes another');
select lives_ok($$ select public.invoice_confirm('00000000-0000-4000-8000-000000130543', pg_temp.k('05')) $$,
  'and the delivery is received');
reset role;
select is(pg_temp.qty('29'), 3::numeric, 'into the product chosen');

select * from finish();
rollback;
