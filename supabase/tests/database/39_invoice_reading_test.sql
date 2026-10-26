-- MS-129 · Reading an invoice: the upload's files (named, sized and refused in a read-only clinic), invoice_create for
-- admins only, the reading claimed once by extract_invoice, its result saved with the alert and the admins' push and
-- no stock moved, a failure kept with its reason, a reading nobody finished failed after its time, and the invoice set
-- aside by Receive manually instead.
begin;
select plan(67);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000129001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000129002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000129003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'olivia@dentory.test'),
  ('00000000-0000-4000-8000-000000129004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dana@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, trial_ends_at) values
  ('00000000-0000-4000-8000-000000129011', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days'),
  ('00000000-0000-4000-8000-000000129012', 'Lapsed Dental', 'CA', 'CAD', 'America/Toronto', now() - interval '1 day'),
  ('00000000-0000-4000-8000-000000129013', 'Other Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129001', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129002', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000129012', '00000000-0000-4000-8000-000000129003', 'olivia@dentory.test', 'Olivia Grant', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000129013', '00000000-0000-4000-8000-000000129004', 'dana@dentory.test', 'Dana Lee', 'admin', 'active');
insert into public.products (id, clinic_id, name, unit, pack_unit, pack_size) values
  ('00000000-0000-4000-8000-000000129021', '00000000-0000-4000-8000-000000129011', 'Septocaine 4% 1:100,000', 'cartridges', 'box', 50),
  ('00000000-0000-4000-8000-000000129022', '00000000-0000-4000-8000-000000129011', 'Needle 27g short', 'needles', 'box', 100);
insert into public.batches (clinic_id, product_id, qty) values
  ('00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129021', 54);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

-- What a delivery's stock looks like; it must read the same after any reading.
create function pg_temp.stock() returns text language sql as $$
  select format('%s batches, %s units, %s ledger rows, %s open items, %s To buy lines, %s products',
    (select count(*) from public.batches), (select coalesce(sum(qty), 0) from public.batches),
    (select count(*) from public.transactions), (select count(*) from public.open_items),
    (select count(*) from public.to_buy_items), (select count(*) from public.products))
$$;

-- Who may call what ----------------------------------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'public.invoice_create(uuid, uuid, public.invoice_source, text, integer)', 'execute'),
  'anon cannot create an invoice');
select ok(has_function_privilege('authenticated', 'public.invoice_create(uuid, uuid, public.invoice_source, text, integer)', 'execute'),
  'members call invoice_create (admins only, checked inside)');
select ok(has_function_privilege('authenticated', 'public.invoice_detail(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.invoice_discard(uuid)', 'execute'),
  'and invoice_detail and invoice_discard');
select ok(not has_function_privilege('authenticated', 'public.invoice_reading_start(uuid, uuid)', 'execute')
  and not has_function_privilege('authenticated', 'public.invoice_reading_finish(uuid, jsonb)', 'execute')
  and not has_function_privilege('authenticated', 'public.invoice_reading_fail(uuid, text)', 'execute'),
  'the reading''s functions are not for members');
select ok(has_function_privilege('service_role', 'public.invoice_reading_start(uuid, uuid)', 'execute')
  and has_function_privilege('service_role', 'public.invoice_reading_finish(uuid, jsonb)', 'execute')
  and has_function_privilege('service_role', 'public.invoice_reading_fail(uuid, text)', 'execute'),
  'extract_invoice calls them with the service role');
select is((select array[file_size_limit::text, array_to_string(allowed_mime_types, ',')] from storage.buckets where id = 'invoices'),
  array['20000000', 'image/jpeg,application/pdf'], 'the bucket takes JPEG pages and PDFs of up to 20 MB');

-- The upload ---------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000129001');
select lives_ok($$ insert into storage.objects (bucket_id, name) values
  ('invoices', '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129031/page-1.jpg'),
  ('invoices', '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129031/page-2.jpg') $$,
  'an admin uploads an invoice''s pages');
select lives_ok($$ insert into storage.objects (bucket_id, name) values
  ('invoices', '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129032/page-1.pdf') $$,
  'or its PDF');
select throws_ok($$ insert into storage.objects (bucket_id, name) values
  ('invoices', '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129031/notes.txt') $$,
  '42501', null, 'but nothing named otherwise');
select throws_ok($$ insert into storage.objects (bucket_id, name) values
  ('invoices', '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129031/page-21.jpg') $$,
  '42501', null, 'nor a 21st page');
select throws_ok($$ insert into storage.objects (bucket_id, name) values
  ('invoices', '00000000-0000-4000-8000-000000129013/00000000-0000-4000-8000-000000129031/page-1.jpg') $$,
  '42501', null, 'nor into another clinic''s folder');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000129002');
select throws_ok($$ insert into storage.objects (bucket_id, name) values
  ('invoices', '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129033/page-1.jpg') $$,
  '42501', null, 'Staff upload nothing');
reset role;
insert into storage.objects (bucket_id, name) values
  ('invoices', '00000000-0000-4000-8000-000000129012/00000000-0000-4000-8000-000000129034/page-1.jpg');
select pg_temp.act_as('00000000-0000-4000-8000-000000129003');
select throws_ok($$ insert into storage.objects (bucket_id, name) values
  ('invoices', '00000000-0000-4000-8000-000000129012/00000000-0000-4000-8000-000000129035/page-1.jpg') $$,
  '42501', null, 'a read-only clinic uploads no invoice');
select is((select count(*)::integer from storage.objects where bucket_id = 'invoices'
  and name like '00000000-0000-4000-8000-000000129012/%'), 1, 'but its admin still sees the clinic''s files');
-- As the Storage API deletes: it allows the statement its trigger otherwise refuses, and the policy decides.
select set_config('storage.allow_delete_query', 'true', true);
delete from storage.objects where bucket_id = 'invoices'
  and name = '00000000-0000-4000-8000-000000129012/00000000-0000-4000-8000-000000129034/page-1.jpg';
select set_config('storage.allow_delete_query', 'false', true);
reset role;
select is((select count(*)::integer from storage.objects where bucket_id = 'invoices'
  and name like '00000000-0000-4000-8000-000000129012/%'), 0, 'and deletes them, which stay the clinic''s (PRD §9)');

-- invoice_create -------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000129002');
select throws_ok($$ select public.invoice_create('00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129031', 'camera', 'jpg', 2) $$,
  '42501', 'Only an admin can receive deliveries', 'Staff cannot create an invoice');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000129003');
select throws_ok($$ select public.invoice_create('00000000-0000-4000-8000-000000129012', '00000000-0000-4000-8000-000000129035', 'camera', 'jpg', 1) $$,
  '42501', 'The clinic is read-only until a payment method is added', 'nor a read-only clinic''s admin');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000129001');
select throws_ok($$ select public.invoice_create('00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129036', 'camera', 'jpg', 1) $$,
  '22023', 'The pages did not finish uploading. Try again.', 'an invoice needs its pages uploaded first');
select throws_ok($$ select public.invoice_create('00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129031', 'camera', 'jpg', 3) $$,
  '22023', 'The pages did not finish uploading. Try again.', 'every one of them');
select throws_ok($$ select public.invoice_create('00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129032', 'file', 'pdf', 2) $$,
  '22023', 'An invoice has 1 to 20 JPEG pages, or one PDF', 'a PDF is one file');
select throws_ok($$ select public.invoice_create('00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129032', 'manual', 'pdf', 1) $$,
  '22023', 'An invoice is a photo or a file', 'a manual receipt has no invoice to read');
select throws_ok($$ insert into public.invoices (clinic_id, source, created_by, storage_path) values
  ('00000000-0000-4000-8000-000000129011', 'file', '00000000-0000-4000-8000-000000129001', 'x') $$,
  '42501', null, 'invoices are no longer inserted directly');
select is(public.invoice_create('00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129031', 'camera', 'jpg', 2) - 'created_at',
  jsonb_build_object('id', '00000000-0000-4000-8000-000000129031', 'status', 'reading', 'source', 'camera', 'supplier', null,
    'number', null, 'invoice_date', null, 'total', null, 'currency', null, 'reading_started', false, 'read_at', null,
    'failure_reason', null, 'line_count', 0),
  'an admin creates the invoice for the pages, being read');
select lives_ok($$ select public.invoice_create('00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129031', 'camera', 'jpg', 2) $$,
  'a retry after a lost answer finds the same invoice');
reset role;
select results_eq(
  $$ select clinic_id, storage_path, source::text, status::text, created_by, file_kind, file_count from public.invoices
     where id = '00000000-0000-4000-8000-000000129031' $$,
  $$ values ('00000000-0000-4000-8000-000000129011'::uuid, '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129031',
             'camera', 'reading', '00000000-0000-4000-8000-000000129001'::uuid, 'jpg', 2) $$,
  'one invoice, kept with its folder, its two JPEG pages and who uploaded them');
select pg_temp.act_as('00000000-0000-4000-8000-000000129004');
select throws_ok($$ select public.invoice_create('00000000-0000-4000-8000-000000129013', '00000000-0000-4000-8000-000000129031', 'camera', 'jpg', 2) $$,
  '42501', 'Only an admin can receive deliveries', 'another clinic cannot take the invoice''s id');
select throws_ok($$ select public.invoice_detail('00000000-0000-4000-8000-000000129031') $$,
  '42501', 'Only an admin can receive deliveries', 'nor read it');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000129002');
select throws_ok($$ select public.invoice_detail('00000000-0000-4000-8000-000000129031') $$,
  '42501', 'Only an admin can receive deliveries', 'Staff do not read invoices');
reset role;
-- A PDF's file over 20 MB is refused (sizes as Storage records them).
insert into storage.objects (bucket_id, name, metadata) values
  ('invoices', '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129037/page-1.pdf', '{"size": 20000001}');
select pg_temp.act_as('00000000-0000-4000-8000-000000129001');
select throws_ok($$ select public.invoice_create('00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129037', 'file', 'pdf', 1) $$,
  '22023', 'The pages are over 20 MB', 'pages over 20 MB are refused');
select is(public.invoice_detail('00000000-0000-4000-8000-000000129031') ->> 'status', 'reading', 'the admin reads the invoice''s state');
reset role;

-- invoice_reading_start (extract_invoice) ------------------------------------------------------------------------------
select throws_ok($$ select * from public.invoice_reading_start('00000000-0000-4000-8000-000000129031', '00000000-0000-4000-8000-000000129002') $$,
  '42501', 'Only an admin can receive deliveries', 'a reading is claimed for an admin only');
select throws_ok($$ select * from public.invoice_reading_start('00000000-0000-4000-8000-000000129031', '00000000-0000-4000-8000-000000129004') $$,
  '42501', 'Only an admin can receive deliveries', 'of the invoice''s own clinic');
select throws_ok($$ select * from public.invoice_reading_start('00000000-0000-4000-8000-000000129099', '00000000-0000-4000-8000-000000129001') $$,
  '42501', 'Only an admin can receive deliveries', 'and for an invoice that exists');
select results_eq(
  $$ select clinic_id, storage_path, file_kind, file_count
     from public.invoice_reading_start('00000000-0000-4000-8000-000000129031', '00000000-0000-4000-8000-000000129001') $$,
  $$ values ('00000000-0000-4000-8000-000000129011'::uuid, '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129031', 'jpg', 2) $$,
  'the first claim answers the files to read');
select is((select count(*)::integer from public.invoice_reading_start('00000000-0000-4000-8000-000000129031', '00000000-0000-4000-8000-000000129001')),
  0, 'a second claim answers nothing, so nothing reads it twice');
select pg_temp.act_as('00000000-0000-4000-8000-000000129001');
select is(public.invoice_detail('00000000-0000-4000-8000-000000129031') ->> 'reading_started', 'true', 'the screen sees the reading started');
reset role;
insert into public.invoices (id, clinic_id, storage_path, source, status, created_by, file_kind, file_count) values
  ('00000000-0000-4000-8000-000000129038', '00000000-0000-4000-8000-000000129012',
   '00000000-0000-4000-8000-000000129012/00000000-0000-4000-8000-000000129038', 'camera', 'reading', '00000000-0000-4000-8000-000000129003', 'jpg', 1);
select throws_ok($$ select * from public.invoice_reading_start('00000000-0000-4000-8000-000000129038', '00000000-0000-4000-8000-000000129003') $$,
  '42501', 'The clinic is read-only until a payment method is added', 'a read-only clinic''s invoice is not read');

-- invoice_reading_finish ------------------------------------------------------------------------------------------------
create temp table stock_before as select pg_temp.stock() as stock;
select is(public.invoice_reading_finish('00000000-0000-4000-8000-000000129031', $json$
  {"supplier": "Northbridge Dental Supply", "invoice_number": "INV-10092", "invoice_date": "2026-09-30", "currency": "CAD",
   "total": 520.03, "lines": [
     {"raw": "SEPTOCAINE 4% 1:100,000 CARTRIDGES 50/BX", "qty": 5, "unit": "box", "unit_price": 49.8, "line_total": 249,
      "lot": "B552", "expiry": "2028-03-01", "kind": "product"},
     {"raw": "  ", "qty": 1, "unit": null, "unit_price": null, "line_total": null, "lot": null, "expiry": null, "kind": "product"},
     {"raw": "HANDLING / FUEL SURCHARGE", "qty": 1, "unit": "each", "unit_price": 4.8, "line_total": 4.8,
      "lot": null, "expiry": null, "kind": "fee"}]}
  $json$) ->> 'line_count', '2', 'the reading is saved, a line with no text left out');
select results_eq(
  $$ select status::text, supplier, number, invoice_date, total, currency::text, read_at is not null, raw_extraction ->> 'invoice_number'
     from public.invoices where id = '00000000-0000-4000-8000-000000129031' $$,
  $$ values ('ready', 'Northbridge Dental Supply', 'INV-10092', '2026-09-30'::date, 520.03::numeric, 'CAD', true, 'INV-10092') $$,
  'the invoice is ready, with its supplier, number, date, total and currency, and what was read kept');
select results_eq(
  $$ select n, raw, qty, unit, unit_price, line_total, lot, expiry_month, kind, state::text, read_state::text, product_id
     from public.invoice_lines where invoice_id = '00000000-0000-4000-8000-000000129031' order by n $$,
  $$ values (1, 'SEPTOCAINE 4% 1:100,000 CARTRIDGES 50/BX', 5::numeric, 'box', 49.8::numeric, 249::numeric, 'B552', '2028-03-01'::date,
             'product', 'matched', 'matched', '00000000-0000-4000-8000-000000129021'::uuid),
            (2, 'HANDLING / FUEL SURCHARGE', 1::numeric, 'each', 4.8::numeric, 4.8::numeric, null, null,
             'fee', 'needs_review', 'needs_review', null::uuid) $$,
  'each line is saved with its numbers, lot, expiry month, kind and the state matching gave it');
select is((select array_agg(kind::text) from public.alerts where invoice_id = '00000000-0000-4000-8000-000000129031' and resolved_at is null),
  array['invoice_ready'], 'the delivery waits for review in the bell');
select is((select count(*)::integer from public.push_outbox where invoice_id = '00000000-0000-4000-8000-000000129031' and kind = 'invoice_ready'),
  1, 'and its push is queued for the admins (MS-144)');
select is(pg_temp.stock(), (select stock from stock_before), 'no batch, ledger row, open item, To buy line or product changed');
select is(public.invoice_reading_finish('00000000-0000-4000-8000-000000129031', '{"lines": [{"raw": "AGAIN", "kind": "product"}]}'),
  null, 'a second result for an invoice already read is ignored');
select is((select count(*)::integer from public.invoice_lines where invoice_id = '00000000-0000-4000-8000-000000129031'),
  2, 'its lines stay as read');
select is((select count(*)::integer from public.alerts where invoice_id = '00000000-0000-4000-8000-000000129031'), 1, 'with one alert');

-- The admin resolving a line (MS-130) changes its state, never the state it was read in.
select pg_temp.act_as('00000000-0000-4000-8000-000000129001');
update public.invoice_lines set state = 'skipped' where invoice_id = '00000000-0000-4000-8000-000000129031' and n = 2;
update public.invoice_lines set read_state = 'matched' where invoice_id = '00000000-0000-4000-8000-000000129031' and n = 2;
reset role;
select results_eq(
  $$ select state::text, read_state::text from public.invoice_lines where invoice_id = '00000000-0000-4000-8000-000000129031' and n = 2 $$,
  $$ values ('skipped', 'needs_review') $$, 'a resolved line keeps the state it was read in (MS-147''s matched share)');
select pg_temp.act_as('00000000-0000-4000-8000-000000129001');
select throws_ok($$ insert into public.invoice_lines (clinic_id, invoice_id, n, raw) values
  ('00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129031', 9, 'EXTRA') $$,
  '42501', null, 'lines come from the reading only');
reset role;

-- A reading that finds no lines is refused, and its invoice is failed by extract_invoice.
insert into public.invoices (id, clinic_id, storage_path, source, status, created_by, file_kind, file_count) values
  ('00000000-0000-4000-8000-000000129039', '00000000-0000-4000-8000-000000129011',
   '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129039', 'file', 'reading', '00000000-0000-4000-8000-000000129001', 'pdf', 1);
select throws_ok($$ select public.invoice_reading_finish('00000000-0000-4000-8000-000000129039', '{"supplier": "Someone", "lines": []}') $$,
  '22023', 'A reading needs at least one line', 'a reading with no lines is refused');

-- invoice_reading_fail ------------------------------------------------------------------------------------------------
select lives_ok($$ select public.invoice_reading_fail('00000000-0000-4000-8000-000000129039', 'unreadable') $$, 'a failed reading is recorded');
select results_eq(
  $$ select status::text, failure_reason, read_at is not null from public.invoices where id = '00000000-0000-4000-8000-000000129039' $$,
  $$ values ('failed', 'unreadable', true) $$, 'the invoice is failed with the reason');
select is(public.invoice_reading_finish('00000000-0000-4000-8000-000000129039', '{"lines": [{"raw": "LATE", "kind": "product"}]}'),
  null, 'a result arriving after the failure changes nothing');
select is((select count(*)::integer from public.invoice_lines where invoice_id = '00000000-0000-4000-8000-000000129039'), 0, 'no line is saved');
select lives_ok($$ select public.invoice_reading_fail('00000000-0000-4000-8000-000000129031', 'timeout') $$, 'failing an invoice already read');
select is((select status::text from public.invoices where id = '00000000-0000-4000-8000-000000129031'), 'ready', 'leaves it as it is');
insert into public.invoices (id, clinic_id, storage_path, source, status, created_by, file_kind, file_count) values
  ('00000000-0000-4000-8000-000000129040', '00000000-0000-4000-8000-000000129011',
   '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129040', 'file', 'reading', '00000000-0000-4000-8000-000000129001', 'pdf', 1);
select throws_ok($$ select public.invoice_reading_fail('00000000-0000-4000-8000-000000129040', 'bored') $$,
  '23514', null, 'a reason outside the closed set is refused');

-- Time ---------------------------------------------------------------------------------------------------------------
insert into public.invoices (id, clinic_id, storage_path, source, status, created_by, file_kind, file_count, created_at, read_started_at) values
  ('00000000-0000-4000-8000-000000129041', '00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129041',
   'camera', 'reading', '00000000-0000-4000-8000-000000129001', 'jpg', 1, now() - interval '90 seconds', now() - interval '80 seconds'),
  ('00000000-0000-4000-8000-000000129042', '00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129042',
   'camera', 'reading', '00000000-0000-4000-8000-000000129001', 'jpg', 1, now() - interval '2 minutes', null),
  ('00000000-0000-4000-8000-000000129043', '00000000-0000-4000-8000-000000129011', '00000000-0000-4000-8000-000000129011/00000000-0000-4000-8000-000000129043',
   'camera', 'reading', '00000000-0000-4000-8000-000000129001', 'jpg', 1, now() - interval '20 seconds', now() - interval '15 seconds');
select engine.invoice_reading_timeout();
select results_eq(
  $$ select id, status::text, failure_reason from public.invoices
     where id in ('00000000-0000-4000-8000-000000129041', '00000000-0000-4000-8000-000000129042', '00000000-0000-4000-8000-000000129043')
     order by id $$,
  $$ values ('00000000-0000-4000-8000-000000129041'::uuid, 'failed', 'timeout'),
            ('00000000-0000-4000-8000-000000129042'::uuid, 'failed', 'timeout'),
            ('00000000-0000-4000-8000-000000129043'::uuid, 'reading', null) $$,
  'a reading past its 60 seconds, or one never started, fails with timeout; one still in time goes on');
select ok(exists (select 1 from cron.job where jobname = 'invoice-reading-timeout' and schedule = '* * * * *'),
  'the check runs each minute');

-- Receive manually instead: invoice_discard ----------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000129002');
select throws_ok($$ select public.invoice_discard('00000000-0000-4000-8000-000000129043') $$,
  '42501', 'Only an admin can receive deliveries', 'Staff cannot discard an invoice');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000129001');
select is(public.invoice_discard('00000000-0000-4000-8000-000000129043') ->> 'status', 'discarded', 'an invoice being read is set aside');
reset role;
select is(public.invoice_reading_finish('00000000-0000-4000-8000-000000129043', '{"lines": [{"raw": "LATE", "kind": "product"}]}'),
  null, 'so its reading, when it ends, raises nothing');
select is((select count(*)::integer from public.alerts where invoice_id = '00000000-0000-4000-8000-000000129043'), 0,
  'no delivery waits for review');
select pg_temp.act_as('00000000-0000-4000-8000-000000129001');
select is(public.invoice_discard('00000000-0000-4000-8000-000000129031') ->> 'status', 'discarded', 'an invoice ready to review is set aside too');
reset role;
select is((select count(*)::integer from public.alerts where invoice_id = '00000000-0000-4000-8000-000000129031' and resolved_at is null),
  0, 'and its alert closes');
update public.invoices set status = 'confirmed', confirmed_at = now(), confirmed_by = '00000000-0000-4000-8000-000000129001'
where id = '00000000-0000-4000-8000-000000129040';
select pg_temp.act_as('00000000-0000-4000-8000-000000129001');
select throws_ok($$ select public.invoice_discard('00000000-0000-4000-8000-000000129040') $$,
  '22023', 'This delivery was already received', 'a received invoice stays');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000129003');
select throws_ok($$ select public.invoice_discard('00000000-0000-4000-8000-000000129038') $$,
  '42501', 'The clinic is read-only until a payment method is added', 'a read-only clinic changes no invoice');
reset role;
select is(pg_temp.stock(), (select stock from stock_before), 'and through it all, stock never moved');

select * from finish();
rollback;
