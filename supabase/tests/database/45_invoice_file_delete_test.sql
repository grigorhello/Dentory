-- MS-146 · Delete invoice file: only an admin of the invoice's clinic deletes a received invoice's photo or PDF, in a
-- read-only clinic too (as decided on #117: 48_invoice_file_delete_read_only_test.sql); invoice_file_delete lets go of
-- it (who and when kept), then the invoices bucket lets the admin delete the pages, which it refuses while the received
-- invoice holds them; the lines, the stock received, the ledger and History stay; asked again it keeps the first who
-- and when; an invoice says whether a page of it is still in the bucket, so a deletion cut short is offered again.
begin;
select plan(27);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000146001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@files.test'),
  ('00000000-0000-4000-8000-000000146002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@files.test'),
  ('00000000-0000-4000-8000-000000146004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dana@files.test'),
  ('00000000-0000-4000-8000-000000146005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'daniel@files.test');
insert into public.clinics (id, name, country, currency, time_zone, trial_ends_at) values
  ('00000000-0000-4000-8000-000000146011', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days'),
  ('00000000-0000-4000-8000-000000146013', 'Other Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000146011', '00000000-0000-4000-8000-000000146001', 'sarah@files.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000146011', '00000000-0000-4000-8000-000000146002', 'michael@files.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000146013', '00000000-0000-4000-8000-000000146004', 'dana@files.test', 'Dana Lee', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000146011', '00000000-0000-4000-8000-000000146005', 'daniel@files.test', 'Dr. Daniel Kim', 'admin', 'active');
insert into public.products (id, clinic_id, name, unit, pack_unit, pack_size) values
  ('00000000-0000-4000-8000-000000146021', '00000000-0000-4000-8000-000000146011', 'Septocaine 4% 1:100,000', 'cartridges', 'box', 50);
insert into public.batches (clinic_id, product_id, qty) values
  ('00000000-0000-4000-8000-000000146011', '00000000-0000-4000-8000-000000146021', 54);

-- 31: Patterson's delivery, photographed on two pages, received below; 32: an invoice waiting for review; 34: a received
-- PDF.
insert into public.invoices (id, clinic_id, storage_path, source, status, supplier, number, total, currency, created_by, file_kind,
  file_count, confirmed_at, confirmed_by) values
  ('00000000-0000-4000-8000-000000146031', '00000000-0000-4000-8000-000000146011',
   '00000000-0000-4000-8000-000000146011/00000000-0000-4000-8000-000000146031', 'camera', 'ready', 'Patterson', 'INV-10092', 249, 'CAD',
   '00000000-0000-4000-8000-000000146001', 'jpg', 2, null, null),
  ('00000000-0000-4000-8000-000000146032', '00000000-0000-4000-8000-000000146011',
   '00000000-0000-4000-8000-000000146011/00000000-0000-4000-8000-000000146032', 'camera', 'ready', 'Patterson', 'INV-2', 10, null,
   '00000000-0000-4000-8000-000000146001', 'jpg', 1, null, null),
  ('00000000-0000-4000-8000-000000146034', '00000000-0000-4000-8000-000000146011',
   '00000000-0000-4000-8000-000000146011/00000000-0000-4000-8000-000000146034', 'file', 'confirmed', 'Benco', 'B-7', 12, null,
   '00000000-0000-4000-8000-000000146001', 'pdf', 1, now() - interval '1 day', '00000000-0000-4000-8000-000000146001');
insert into public.invoice_lines (id, clinic_id, invoice_id, n, raw, qty, unit, unit_price, line_total, kind, state, read_state,
  product_id, lot, expiry_month) values
  ('00000000-0000-4000-8000-000000146051', '00000000-0000-4000-8000-000000146011', '00000000-0000-4000-8000-000000146031', 1,
   'SEPTO 4% 1:100K 50/BX', 5, 'boxes', 49.80, 249.00, 'product', 'matched', 'matched', '00000000-0000-4000-8000-000000146021', 'B441',
   '2028-03-01');
insert into storage.objects (bucket_id, name) values
  ('invoices', '00000000-0000-4000-8000-000000146011/00000000-0000-4000-8000-000000146031/page-1.jpg'),
  ('invoices', '00000000-0000-4000-8000-000000146011/00000000-0000-4000-8000-000000146031/page-2.jpg'),
  ('invoices', '00000000-0000-4000-8000-000000146011/00000000-0000-4000-8000-000000146032/page-1.jpg'),
  ('invoices', '00000000-0000-4000-8000-000000146011/00000000-0000-4000-8000-000000146034/page-1.pdf');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
-- An invoice of this test by its two last digits.
create function pg_temp.i(p_n text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000001460' || p_n)::uuid
$$;
-- The pages of an invoice still in the bucket.
create function pg_temp.pages(p_n text) returns integer language sql as $$
  select count(*)::integer from storage.objects where bucket_id = 'invoices' and name like '%/' || pg_temp.i(p_n) || '/%'
$$;
-- Deletes an invoice's pages as the Storage API deletes them for the caller: it allows the statement the bucket's
-- trigger otherwise refuses, and the policies decide.
create function pg_temp.delete_pages(p_n text) returns void language plpgsql as $$
begin
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects where bucket_id = 'invoices' and name like '%/' || pg_temp.i(p_n) || '/%';
  perform set_config('storage.allow_delete_query', 'false', true);
end;
$$;

-- Who may call it --------------------------------------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'public.invoice_file_delete(uuid)', 'execute'), 'anon cannot delete an invoice file');
select ok(has_function_privilege('authenticated', 'public.invoice_file_delete(uuid)', 'execute'),
  'members call invoice_file_delete (admins only, checked inside)');
select is((select format('%s names: %s, %s … %s', array_length(a, 1), a[1], a[2], a[21])
    from (select engine.invoice_page_names(pg_temp.i('11'), pg_temp.i('31')) a) x),
  '21 names: 00000000-0000-4000-8000-000000146011/00000000-0000-4000-8000-000000146031/page-1.jpg, '
  || '00000000-0000-4000-8000-000000146011/00000000-0000-4000-8000-000000146031/page-2.jpg … '
  || '00000000-0000-4000-8000-000000146011/00000000-0000-4000-8000-000000146031/page-1.pdf',
  'an invoice''s pages can have the 21 names the bucket takes: 20 photos, or one PDF');

-- A received invoice keeps its pages while it holds them ------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000146001');
select set_config('test.confirm', public.invoice_confirm(pg_temp.i('31'), '00000000-0000-4000-8000-000000146091')::text, true);
select is(public.invoice_detail(pg_temp.i('31')) ->> 'has_file', 'true', 'a received invoice has its photo');
select pg_temp.delete_pages('31');
reset role;
select is(pg_temp.pages('31'), 2, 'and the bucket does not let its admin delete the pages while the invoice holds them (MS-131)');

-- Who may delete the file --------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000146002');
select throws_ok($$ select public.invoice_file_delete(pg_temp.i('31')) $$,
  '42501', 'Only an admin can delete invoice files', 'Staff cannot delete an invoice file');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000146004');
select throws_ok($$ select public.invoice_file_delete(pg_temp.i('31')) $$,
  '42501', 'Only an admin can delete invoice files', 'nor another clinic''s admin');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000146001');
select throws_ok($$ select public.invoice_file_delete(pg_temp.i('32')) $$,
  '22023', 'Only a received invoice''s file can be deleted', 'an invoice waiting for review is discarded instead (MS-130)');
select throws_ok($$ select public.invoice_file_delete('00000000-0000-4000-8000-000000146099') $$,
  '42501', 'Only an admin can delete invoice files', 'an invoice that does not exist is refused like another clinic''s');
reset role;
select is((select count(*)::integer from public.invoices where id in (pg_temp.i('31'), pg_temp.i('32'))
    and (file_deleted_at is not null or storage_path is null)), 0,
  'a refusal lets go of nothing');
select is(pg_temp.pages('31') + pg_temp.pages('32'), 3, 'and deletes no page');

-- Delete invoice file -------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000146001');
select is((select jsonb_build_object('status', d -> 'status', 'has_file', d -> 'has_file', 'by', d -> 'file_deleted_by_name',
    'when', (d ->> 'file_deleted_at') is not null)
    from (select public.invoice_file_delete(pg_temp.i('31')) d) x),
  jsonb_build_object('status', 'confirmed', 'has_file', true, 'by', 'Sarah Mitchell', 'when', true),
  'the admin deletes the received invoice''s file: it answers who and when, the pages still there for the app to delete');
reset role;
select results_eq(
  $$ select status::text, storage_path, file_kind, file_count, file_deleted_by, file_deleted_at is not null, confirmed_by
     from public.invoices where id = pg_temp.i('31') $$,
  $$ values ('confirmed', null::text, null::text, null::integer, '00000000-0000-4000-8000-000000146001'::uuid, true,
             '00000000-0000-4000-8000-000000146001'::uuid) $$,
  'the invoice lets go of its folder, as the ticket says (storage_path null), and stays received');
select pg_temp.act_as('00000000-0000-4000-8000-000000146002');
select pg_temp.delete_pages('31');
reset role;
select is(pg_temp.pages('31'), 2, 'Staff still delete none of its pages');
select pg_temp.act_as('00000000-0000-4000-8000-000000146004');
select pg_temp.delete_pages('31');
reset role;
select is(pg_temp.pages('31'), 2, 'nor does another clinic''s admin');
select pg_temp.act_as('00000000-0000-4000-8000-000000146001');
select pg_temp.delete_pages('31');
reset role;
select is(pg_temp.pages('31'), 0, 'the admin''s app then deletes them: the file is gone from Storage (the acceptance criterion)');
select pg_temp.act_as('00000000-0000-4000-8000-000000146001');
select is((select format('%s · %s · %s lines', d ->> 'status', d ->> 'has_file', jsonb_array_length(d -> 'lines'))
    from (select public.invoice_detail(pg_temp.i('31')) d) x),
  'confirmed · false · 1 lines', 'the invoice opens received, with no file and its lines (the acceptance criterion)');
reset role;
select is((select format('%s rows · %s', count(*), sum(delta)) from public.transactions
    where action_id = current_setting('test.confirm')::uuid),
  '1 rows · 250.00', 'the ledger keeps the delivery (the acceptance criterion)');
select is((select quantity from public.product_stock where product_id = '00000000-0000-4000-8000-000000146021'), 304::numeric,
  'and the stock received stays');
select pg_temp.act_as('00000000-0000-4000-8000-000000146001');
select results_eq(
  $$ select subject, invoice_id from public.activity_history('00000000-0000-4000-8000-000000146011', 'receiving') $$,
  $$ values ('Septocaine 4% 1:100,000', '00000000-0000-4000-8000-000000146031'::uuid) $$,
  'History keeps the receipt, which still opens its invoice');
reset role;
select throws_ok($$ update public.invoices set storage_path = null where id = '00000000-0000-4000-8000-000000146034' $$,
  '23514', null, 'a received invoice from a file keeps its folder until its file is deleted');

-- Asked again ---------------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000146005');
select is(public.invoice_file_delete(pg_temp.i('31')) ->> 'file_deleted_by_name', 'Sarah Mitchell',
  'asked again by another admin, it changes nothing and keeps who deleted the file');
select throws_ok($$ select public.invoice_discard(pg_temp.i('31')) $$,
  '22023', 'This delivery was already received', 'a received invoice without its file is still not discarded');
reset role;

-- A deletion cut short ------------------------------------------------------------------------------------------------------
-- The connection drops once the PDF is let go and before its page is deleted: the invoice says it still has its file,
-- so Delete invoice file is offered again, and answers the same until the page is deleted.
select pg_temp.act_as('00000000-0000-4000-8000-000000146001');
select is(public.invoice_file_delete(pg_temp.i('34')) ->> 'has_file', 'true', 'a PDF let go keeps its page until the app deletes it');
select is(public.invoice_detail(pg_temp.i('34')) ->> 'has_file', 'true', 'so the received invoice still offers the deletion');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000146005');
select is(public.invoice_file_delete(pg_temp.i('34')) ->> 'file_deleted_by_name', 'Sarah Mitchell',
  'which, asked again by another admin, keeps the first who and when');
select pg_temp.delete_pages('34');
select is(public.invoice_detail(pg_temp.i('34')) ->> 'has_file', 'false', 'and its app deletes the page left: the file is gone');
reset role;

select * from finish();
rollback;
