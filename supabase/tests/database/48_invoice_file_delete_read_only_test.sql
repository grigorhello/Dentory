-- MS-146 fix (Refs #117) · Delete invoice file in read-only mode, as decided on #117 on 2026-10-26: the admin of a
-- clinic whose trial ended without a card deletes a received invoice's photo, and the invoices bucket then lets that
-- admin, and no one else, delete its pages; Staff, another clinic's admin and an invoice not received are refused as in
-- a clinic that may write; the lines, the stock received, the ledger and History stay; and every other write of the
-- read-only clinic is still refused, Discard invoice included.
begin;
select plan(20);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000146501', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'olivia@lapsed.test'),
  ('00000000-0000-4000-8000-000000146502', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'noah@lapsed.test'),
  ('00000000-0000-4000-8000-000000146503', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dana@lapsed.test');
-- Lapsed Dental receives a delivery while its trial runs, then the trial ends without a card (below).
insert into public.clinics (id, name, country, currency, time_zone, trial_ends_at) values
  ('00000000-0000-4000-8000-000000146511', 'Lapsed Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days'),
  ('00000000-0000-4000-8000-000000146512', 'Other Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '30 days');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000146511', '00000000-0000-4000-8000-000000146501', 'olivia@lapsed.test', 'Olivia Grant', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000146511', '00000000-0000-4000-8000-000000146502', 'noah@lapsed.test', 'Noah Park', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000146512', '00000000-0000-4000-8000-000000146503', 'dana@lapsed.test', 'Dana Lee', 'admin', 'active');
insert into public.products (id, clinic_id, name, unit, pack_unit, pack_size) values
  ('00000000-0000-4000-8000-000000146521', '00000000-0000-4000-8000-000000146511', 'Septocaine 4% 1:100,000', 'cartridges', 'box', 50);
insert into public.batches (clinic_id, product_id, qty) values
  ('00000000-0000-4000-8000-000000146511', '00000000-0000-4000-8000-000000146521', 54);

-- 31: Patterson's delivery, photographed on two pages, received below while the trial runs; 32: an invoice still
-- waiting for review when the trial ends.
insert into public.invoices (id, clinic_id, storage_path, source, status, supplier, number, total, currency, created_by, file_kind,
  file_count) values
  ('00000000-0000-4000-8000-000000146531', '00000000-0000-4000-8000-000000146511',
   '00000000-0000-4000-8000-000000146511/00000000-0000-4000-8000-000000146531', 'camera', 'ready', 'Patterson', 'INV-10092', 249, 'CAD',
   '00000000-0000-4000-8000-000000146501', 'jpg', 2),
  ('00000000-0000-4000-8000-000000146532', '00000000-0000-4000-8000-000000146511',
   '00000000-0000-4000-8000-000000146511/00000000-0000-4000-8000-000000146532', 'camera', 'ready', 'Patterson', 'INV-2', 10, null,
   '00000000-0000-4000-8000-000000146501', 'jpg', 1);
insert into public.invoice_lines (id, clinic_id, invoice_id, n, raw, qty, unit, unit_price, line_total, kind, state, read_state,
  product_id, lot, expiry_month) values
  ('00000000-0000-4000-8000-000000146551', '00000000-0000-4000-8000-000000146511', '00000000-0000-4000-8000-000000146531', 1,
   'SEPTO 4% 1:100K 50/BX', 5, 'boxes', 49.80, 249.00, 'product', 'matched', 'matched', '00000000-0000-4000-8000-000000146521', 'B441',
   '2028-03-01');
insert into storage.objects (bucket_id, name) values
  ('invoices', '00000000-0000-4000-8000-000000146511/00000000-0000-4000-8000-000000146531/page-1.jpg'),
  ('invoices', '00000000-0000-4000-8000-000000146511/00000000-0000-4000-8000-000000146531/page-2.jpg'),
  ('invoices', '00000000-0000-4000-8000-000000146511/00000000-0000-4000-8000-000000146532/page-1.jpg');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
-- An invoice of this test by its two last digits.
create function pg_temp.i(p_n text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000001465' || p_n)::uuid
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

-- The delivery is received while the trial runs; then the trial ends without a card ------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000146501');
select set_config('test.confirm', public.invoice_confirm(pg_temp.i('31'), '00000000-0000-4000-8000-000000146591')::text, true);
reset role;
update public.clinics set trial_ends_at = now() - interval '1 day' where id = '00000000-0000-4000-8000-000000146511';
select ok(not public.clinic_can_write('00000000-0000-4000-8000-000000146511'),
  'Lapsed Dental is read-only: its trial ended without a card (MS-142)');

-- The function --------------------------------------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'public.invoice_file_delete(uuid)', 'execute'),
  'the anon key still cannot delete an invoice file');
select ok((select p.prosecdef and 'search_path=""' = any (p.proconfig) from pg_catalog.pg_proc p
    where p.oid = 'public.invoice_file_delete(uuid)'::regprocedure),
  'it is still security definer on an empty search path (46_security_invariants_test.sql)');

-- Who is still refused in a read-only clinic ----------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000146502');
select throws_ok($$ select public.invoice_file_delete(pg_temp.i('31')) $$,
  '42501', 'Only an admin can delete invoice files', 'Staff of a read-only clinic still cannot delete an invoice file');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000146503');
select throws_ok($$ select public.invoice_file_delete(pg_temp.i('31')) $$,
  '42501', 'Only an admin can delete invoice files', 'nor another clinic''s admin');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000146501');
select throws_ok($$ select public.invoice_file_delete(pg_temp.i('32')) $$,
  '22023', 'Only a received invoice''s file can be deleted', 'nor the admin, for an invoice not received');
select throws_ok($$ select public.invoice_discard(pg_temp.i('32')) $$,
  '42501', 'The clinic is read-only until a payment method is added',
  'which stays waiting: discarding it is a write the read-only clinic is still refused (MS-142)');
reset role;
select results_eq(
  $$ select status::text, storage_path is not null, file_deleted_at is null from public.invoices
     where id in (pg_temp.i('31'), pg_temp.i('32')) order by id $$,
  $$ values ('confirmed', true, true), ('ready', true, true) $$,
  'a refusal lets go of nothing, and the invoice waiting for review still waits');
select is(pg_temp.pages('31') + pg_temp.pages('32'), 3, 'and deletes no page');

-- The bucket keeps a received invoice's pages while the invoice holds them, read-only or not ----------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000146501');
select pg_temp.delete_pages('31');
reset role;
select is(pg_temp.pages('31'), 2, 'the bucket does not let the admin delete the pages before the invoice lets go (MS-131)');

-- Delete invoice file in a read-only clinic -----------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000146501');
select is((select jsonb_build_object('status', d -> 'status', 'has_file', d -> 'has_file', 'by', d -> 'file_deleted_by_name',
    'when', (d ->> 'file_deleted_at') is not null)
    from (select public.invoice_file_delete(pg_temp.i('31')) d) x),
  jsonb_build_object('status', 'confirmed', 'has_file', true, 'by', 'Olivia Grant', 'when', true),
  'the read-only clinic''s admin deletes the received invoice''s file (#117): who and when, the pages left for the app');
reset role;
select results_eq(
  $$ select status::text, storage_path, file_kind, file_count, file_deleted_by, file_deleted_at is not null
     from public.invoices where id = pg_temp.i('31') $$,
  $$ values ('confirmed', null::text, null::text, null::integer, '00000000-0000-4000-8000-000000146501'::uuid, true) $$,
  'the invoice lets go of its folder past the read-only trigger on invoices, and stays received');
select pg_temp.act_as('00000000-0000-4000-8000-000000146502');
select pg_temp.delete_pages('31');
reset role;
select is(pg_temp.pages('31'), 2, 'Staff still delete none of its pages');
select pg_temp.act_as('00000000-0000-4000-8000-000000146503');
select pg_temp.delete_pages('31');
reset role;
select is(pg_temp.pages('31'), 2, 'nor does another clinic''s admin');
select pg_temp.act_as('00000000-0000-4000-8000-000000146501');
select pg_temp.delete_pages('31');
reset role;
select is(pg_temp.pages('31'), 0, 'the admin''s app then deletes them: the file is gone from Storage, read-only or not');

-- What stays ------------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000146501');
select is((select format('%s · %s · %s lines', d ->> 'status', d ->> 'has_file', jsonb_array_length(d -> 'lines'))
    from (select public.invoice_detail(pg_temp.i('31')) d) x),
  'confirmed · false · 1 lines', 'the invoice opens received, with no file and its lines');
reset role;
select is((select format('%s rows · %s', count(*), sum(delta)) from public.transactions
    where action_id = current_setting('test.confirm')::uuid),
  '1 rows · 250.00', 'the ledger keeps the delivery');
select is((select quantity from public.product_stock where product_id = '00000000-0000-4000-8000-000000146521'), 304::numeric,
  'and the stock received stays');
select pg_temp.act_as('00000000-0000-4000-8000-000000146501');
select results_eq(
  $$ select subject, invoice_id from public.activity_history('00000000-0000-4000-8000-000000146511', 'receiving') $$,
  $$ values ('Septocaine 4% 1:100,000', '00000000-0000-4000-8000-000000146531'::uuid) $$,
  'History keeps the receipt, which still opens its invoice');
select is((select format('%s · %s', d ->> 'file_deleted_by_name', d ->> 'has_file')
    from (select public.invoice_file_delete(pg_temp.i('31')) d) x),
  'Olivia Grant · false', 'asked again, it changes nothing');
reset role;

select * from finish();
rollback;
