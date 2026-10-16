-- product_stock: unopened is the sum of the batches, multi-use products add their open items,
-- undated quantity is reported as missing expiry, and empty batches do not set the soonest expiry.
begin;
select plan(14);

insert into auth.users (id, instance_id, aud, role, email)
values ('00000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tap@medisave.test');
insert into public.clinics (id, name, country, currency)
values ('00000000-0000-4000-8000-0000000000c1', 'Smile Dental', 'US', 'USD');

-- A countable product: two dated batches, an undated one and an empty one that expires first.
insert into public.products (id, clinic_id, name, unit, tracking)
values ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000c1', 'Septocaine 4% 1:100,000', 'cartridges', 'countable');
insert into public.batches (clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', '2026-12-01', 'A112', 20),
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', '2027-03-01', 'B441', 34),
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', null, null, 3),
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', '2026-11-01', 'OLD', 0);

-- A multi-use product: two unopened bottles with no expiry, one open and one finished.
insert into public.products (id, clinic_id, name, unit, tracking)
values ('00000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-0000000000c1', 'Bonding agent', 'bottles', 'multi_use');
insert into public.batches (clinic_id, product_id, expiry_month, qty)
values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a2', null, 2);
insert into public.open_items (clinic_id, product_id, opened_by) values
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-000000000001');
insert into public.open_items (clinic_id, product_id, opened_by, finished_at, finished_by) values
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-000000000001', now(), '00000000-0000-4000-8000-000000000001');

-- A product with nothing yet.
insert into public.products (id, clinic_id, name, unit)
values ('00000000-0000-4000-8000-0000000000a3', '00000000-0000-4000-8000-0000000000c1', 'Suction tips', 'bags');

select is(unopened, 57::numeric, 'countable: unopened sums every batch') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a1';
select is(open_count, 0, 'countable: no open items') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a1';
select is(quantity, 57::numeric, 'countable: quantity is the batch sum') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a1';
select is(missing_expiry_qty, 3::numeric, 'countable: the undated batch is missing expiry') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a1';
select is(soonest_expiry, '2026-12-01'::date, 'countable: an empty batch does not set the soonest expiry') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a1';

select is(unopened, 2::numeric, 'multi-use: unopened counts the bottles in stock') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a2';
select is(open_count, 1, 'multi-use: finished bottles are not open') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a2';
select is(quantity, 3::numeric, 'multi-use: quantity is unopened plus open') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a2';
select is(missing_expiry_qty, 2::numeric, 'multi-use: the undated batch is missing expiry') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a2';
select is(soonest_expiry, null::date, 'multi-use: no dated batch, no soonest expiry') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a2';

select is(unopened, 0::numeric, 'empty product: unopened is 0') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a3';
select is(open_count, 0, 'empty product: open count is 0') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a3';
select is(quantity, 0::numeric, 'empty product: quantity is 0') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a3';
select is(missing_expiry_qty, 0::numeric, 'empty product: nothing is missing expiry') from public.product_stock where product_id = '00000000-0000-4000-8000-0000000000a3';

select * from finish();
rollback;
