-- The rules the schema enforces on its own: clinic isolation of references, the batch and expiry
-- rules of MS-100 D8 and D9, and the uniqueness of emails, names, open To buy lines and open alerts.
begin;
select plan(22);

insert into auth.users (id, instance_id, aud, role, email)
values ('00000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tap@medisave.test');
insert into public.clinics (id, name, country, currency) values
  ('00000000-0000-4000-8000-0000000000c1', 'Smile Dental', 'US', 'USD'),
  ('00000000-0000-4000-8000-0000000000c2', 'Other Dental', 'CA', 'CAD');
insert into public.categories (id, clinic_id, name) values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000c1', 'Anesthetic'),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000c2', 'Anesthetic');
insert into public.products (id, clinic_id, name, unit) values
  ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000c1', 'Septocaine 4% 1:100,000', 'cartridges');

-- Clinic isolation of references
select throws_ok($$
  insert into public.products (clinic_id, name, unit, category_id)
  values ('00000000-0000-4000-8000-0000000000c1', 'Composite A2', 'syringes', '00000000-0000-4000-8000-0000000000e2')
$$, '23503', null, 'a product cannot use another clinic''s category');
select throws_ok($$
  insert into public.batches (clinic_id, product_id, qty)
  values ('00000000-0000-4000-8000-0000000000c2', '00000000-0000-4000-8000-0000000000a1', 1)
$$, '23503', null, 'a batch cannot sit in another clinic than its product');
insert into public.invoices (id, clinic_id, source, created_by)
values ('00000000-0000-4000-8000-0000000000d2', '00000000-0000-4000-8000-0000000000c2', 'manual', '00000000-0000-4000-8000-000000000001');
select throws_ok($$
  insert into public.invoice_lines (clinic_id, invoice_id, n, raw, suggested_product_id)
  values ('00000000-0000-4000-8000-0000000000c2', '00000000-0000-4000-8000-0000000000d2', 1, 'SEPTO 4%', '00000000-0000-4000-8000-0000000000a1')
$$, '23503', null, 'an invoice line cannot suggest another clinic''s product');
insert into public.procedure_templates (id, clinic_id, name)
values ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000c1', 'Root canal');
select throws_ok($$
  insert into public.procedure_events (clinic_id, template_id, name, started_by)
  values ('00000000-0000-4000-8000-0000000000c2', '00000000-0000-4000-8000-0000000000b1', 'Root canal', '00000000-0000-4000-8000-000000000001')
$$, '23503', null, 'a procedure cannot start from another clinic''s template');

insert into public.products (id, clinic_id, name, unit) values
  ('00000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-0000000000c2', 'Septocaine 4% 1:100,000', 'cartridges');
insert into public.transactions (id, clinic_id, product_id, type, delta, qty_before, qty_after, by_user, ref_type, action_id)
values ('00000000-0000-4000-8000-0000000000f0', '00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1',
        'count', 2, 0, 2, '00000000-0000-4000-8000-000000000001', 'count_session', gen_random_uuid());
select throws_ok($$
  insert into public.transactions (clinic_id, product_id, type, delta, qty_before, qty_after, by_user, ref_type, reverses_id, action_id)
  values ('00000000-0000-4000-8000-0000000000c2', '00000000-0000-4000-8000-0000000000a2', 'cancellation', -2, 2, 0,
          '00000000-0000-4000-8000-000000000001', 'undo', '00000000-0000-4000-8000-0000000000f0', gen_random_uuid())
$$, '23503', null, 'a reversal cannot point at another clinic''s transaction');

-- Products are archived, never deleted; an account with an active membership stays
select throws_ok($$ delete from public.products where id = '00000000-0000-4000-8000-0000000000a1' $$,
  '23001', null, 'deleting a product raises');
insert into public.memberships (clinic_id, user_id, email, role, status)
values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-000000000001', 'tap@medisave.test', 'admin', 'active');
select throws_ok($$ delete from auth.users where id = '00000000-0000-4000-8000-000000000001' $$,
  '23503', null, 'a user with an active membership cannot be removed');

-- Packs: both or neither, and a pack holds more than one unit
select throws_ok($$
  insert into public.products (clinic_id, name, unit, pack_unit) values ('00000000-0000-4000-8000-0000000000c1', 'Gloves', 'boxes', 'case')
$$, '23514', null, 'a pack unit needs a pack size');
select throws_ok($$
  insert into public.products (clinic_id, name, unit, pack_unit, pack_size) values ('00000000-0000-4000-8000-0000000000c1', 'Gloves', 'boxes', 'case', 1)
$$, '23514', null, 'a pack holds more than one unit');
select lives_ok($$
  insert into public.products (clinic_id, name, unit, pack_unit, pack_size) values ('00000000-0000-4000-8000-0000000000c1', 'Gloves', 'boxes', 'case', 10)
$$, '1 case = 10 boxes is a valid pack');

-- Batches (MS-100 D9) and expiry months
select throws_ok($$
  insert into public.batches (clinic_id, product_id, expiry_month, qty)
  values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', '2026-12-01', -1)
$$, '23514', null, 'a dated batch cannot go negative');
select lives_ok($$
  insert into public.batches (clinic_id, product_id, expiry_month, qty)
  values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', null, -1)
$$, 'the undated batch may go negative');
select throws_ok($$
  insert into public.batches (clinic_id, product_id, expiry_month, qty)
  values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', '2026-12-15', 1)
$$, '23514', null, 'expiry_month must be the first day of a month');

-- Clinic settings (MS-100 D8)
select throws_ok($$ update public.clinics set expiry_thresholds = '{30}' where id = '00000000-0000-4000-8000-0000000000c1' $$,
  '23514', null, 'thresholds must be {30,60,90}, {60,90} or {90}');
select lives_ok($$ update public.clinics set expiry_thresholds = '{60,90}' where id = '00000000-0000-4000-8000-0000000000c1' $$,
  '{60,90} is an allowed threshold set');

-- Uniqueness
insert into public.memberships (clinic_id, email, role) values ('00000000-0000-4000-8000-0000000000c1', 'Sarah@clinic.com', 'staff');
select throws_ok($$
  insert into public.memberships (clinic_id, email, role) values ('00000000-0000-4000-8000-0000000000c1', 'sarah@CLINIC.com', 'staff')
$$, '23505', null, 'one membership per email per clinic, whatever the case');
select throws_ok($$
  insert into public.categories (clinic_id, name) values ('00000000-0000-4000-8000-0000000000c1', 'ANESTHETIC')
$$, '23505', null, 'one category per name per clinic, whatever the case');

insert into public.to_buy_items (clinic_id, product_id, qty) values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', 6);
select throws_ok($$
  insert into public.to_buy_items (clinic_id, product_id, qty) values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', 2)
$$, '23505', null, 'one open To buy line per product');
update public.to_buy_items set status = 'ordered', ordered_at = now(), ordered_by = '00000000-0000-4000-8000-000000000001'
where product_id = '00000000-0000-4000-8000-0000000000a1';
select lives_ok($$
  insert into public.to_buy_items (clinic_id, product_id, qty) values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', 2)
$$, 'once ordered, the product can be on the list again');

insert into public.alerts (clinic_id, kind, product_id) values ('00000000-0000-4000-8000-0000000000c1', 'low', '00000000-0000-4000-8000-0000000000a1');
select throws_ok($$
  insert into public.alerts (clinic_id, kind, product_id) values ('00000000-0000-4000-8000-0000000000c1', 'low', '00000000-0000-4000-8000-0000000000a1')
$$, '23505', null, 'the same alert cannot be open twice');
update public.alerts set resolved_at = now() where kind = 'low';
select lives_ok($$
  insert into public.alerts (clinic_id, kind, product_id) values ('00000000-0000-4000-8000-0000000000c1', 'low', '00000000-0000-4000-8000-0000000000a1')
$$, 'a resolved alert can open again');

-- Cancelling a procedure needs a note
insert into public.procedure_events (id, clinic_id, name, started_by)
values ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000c1', 'Root canal', '00000000-0000-4000-8000-000000000001');
select throws_ok($$
  update public.procedure_events set cancelled_at = now(), cancelled_by = '00000000-0000-4000-8000-000000000001'
  where id = '00000000-0000-4000-8000-0000000000f1'
$$, '23514', null, 'cancelling a procedure requires a note');

select * from finish();
rollback;
