-- MS-143 · Export CSV: who may start an export and how often, the job's end, and the rows of products.csv,
-- batches.csv and transactions.csv.
begin;
select plan(22);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000018401', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000018402', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000018403', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'daniel@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone) values
  ('00000000-0000-4000-8000-000000018411', 'Clinique Évangéline', 'CA', 'CAD', 'America/Toronto');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018401', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018402', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018403', 'daniel@dentory.test', 'Dr. Daniel Kim', 'admin', 'active');
insert into public.categories (id, clinic_id, name) values
  ('00000000-0000-4000-8000-000000018421', '00000000-0000-4000-8000-000000018411', 'Anesthetic');
insert into public.products (id, clinic_id, name, category_id, unit, pack_unit, pack_size, minimum, target, supplier,
  location, last_unit_cost, archived_at) values
  ('00000000-0000-4000-8000-000000018431', '00000000-0000-4000-8000-000000018411', 'Septocaine 4% "épi"',
   '00000000-0000-4000-8000-000000018421', 'cartridges', 'box', 50, 20, 100, 'Patterson', 'Op 1', 1.80, null),
  ('00000000-0000-4000-8000-000000018432', '00000000-0000-4000-8000-000000018411', 'Old cement', null, 'tubes',
   null, null, 0, 0, null, null, null, '2026-09-30 15:00:00+00');
insert into public.batches (clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018431', '2027-03-01', 'S1', 30),
  ('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018431', '2026-12-01', 'S0', 0);
insert into public.transactions (clinic_id, product_id, type, delta, qty_before, qty_after, by_user, at, ref_type,
  ref_label, reason, note, action_id) values
  ('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018431', 'receiving', 40, 0, 40,
   '00000000-0000-4000-8000-000000018401', '2026-10-01 13:00:00+00', 'invoice', 'Patterson INV-10092', null, null,
   gen_random_uuid()),
  ('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018431', 'adjustment', -10, 40, 30,
   '00000000-0000-4000-8000-000000018402', '2026-10-02 14:30:00+00', 'manual', null, 'Damaged', 'Dropped, "cracked"',
   gen_random_uuid());

select ok(not has_function_privilege('authenticated', 'public.export_job_start(uuid, uuid)', 'execute'),
  'members cannot start an export themselves');
select ok(not has_function_privilege('authenticated', 'public.export_data(uuid)', 'execute'),
  'nor read the export''s rows');
select ok(not has_function_privilege('authenticated', 'public.export_transactions(uuid)', 'execute'),
  'nor the ledger''s');
select ok(has_function_privilege('service_role', 'public.export_data(uuid)', 'execute'),
  'the export function reads them');
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-4000-8000-000000018401', 'role', 'authenticated')::text, true);
set local role authenticated;
select throws_ok(
  $$insert into public.export_jobs (clinic_id, requested_by) values
    ('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018401')$$,
  '42501', null, 'an admin cannot add a job around the limit'
);
reset role;

-- Who may start one, and how often.
select throws_ok(
  $$select * from public.export_job_start('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018402')$$,
  '42501', 'Only an admin can export the clinic''s data', 'Staff cannot export'
);
create temp table started on commit drop as
  select * from public.export_job_start('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018401');
select results_eq($$select email, clinic_name, day from started$$,
  $$values ('sarah@dentory.test', 'Clinique Évangéline', to_char(now() at time zone 'America/Toronto', 'YYYY-MM-DD'))$$,
  'the admin starts one, to be sent to their address, dated at the clinic');
select is((select status::text from public.export_jobs where id = (select job_id from started)), 'running',
  'the job is running');
select throws_ok(
  $$select * from public.export_job_start('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018401')$$,
  '22023', 'An export started less than 10 minutes ago. It is on its way to your email.',
  'one export every 10 minutes'
);
select throws_ok(
  $$select * from public.export_job_start('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018403')$$,
  '22023', 'Sarah Mitchell started an export less than 10 minutes ago. It goes to sarah@dentory.test.',
  'another admin is told whose export it is and where it went'
);
select ok((select local_time from started) ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$',
  'the time at the clinic, for the files inside the zip');
select public.export_job_finish((select job_id from started), null);
select is((select status::text from public.export_jobs where id = (select job_id from started)), 'failed',
  'a job without a file failed');
select lives_ok(
  $$select * from public.export_job_start('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018401')$$,
  'and a failed export frees the next one at once'
);
select public.export_job_finish(
  (select id from public.export_jobs where status = 'running' and clinic_id = '00000000-0000-4000-8000-000000018411'),
  '00000000-0000-4000-8000-000000018411/export.zip');
select is((select count(*)::integer from public.export_jobs where status = 'done'
  and file_path = '00000000-0000-4000-8000-000000018411/export.zip'), 1, 'a job with its file is done');
update public.export_jobs set created_at = now() - interval '11 minutes' where clinic_id = '00000000-0000-4000-8000-000000018411';
select lives_ok(
  $$select * from public.export_job_start('00000000-0000-4000-8000-000000018411', '00000000-0000-4000-8000-000000018401')$$,
  'ten minutes later the next one starts'
);

-- The rows.
select results_eq(
  $$select name, category, unit, pack_unit, pack_size, tracking, minimum, target, supplier, location, quantity, unopened,
           open, last_unit_cost, status, archived
    from public.export_products('00000000-0000-4000-8000-000000018411')$$,
  $$values
    ('Septocaine 4% "épi"', 'Anesthetic', 'cartridges', 'box', 50, 'Countable', 20.00::numeric, 100.00::numeric,
     'Patterson', 'Op 1', 30.00::numeric, 30.00::numeric, 0, 1.8000::numeric, 'Healthy', null::date),
    ('Old cement', null, 'tubes', null, null, 'Countable', 0.00::numeric, 0.00::numeric, null, null, 0.00::numeric,
     0.00::numeric, 0, null::numeric, 'Out of stock', '2026-09-30'::date)$$,
  'products.csv: every product, archived last with its day, stock and status in words'
);
select results_eq(
  $$select product, expiry_month, lot, qty from public.export_batches('00000000-0000-4000-8000-000000018411')$$,
  $$values ('Septocaine 4% "épi"', '2027-03', 'S1', 30.00::numeric)$$,
  'batches.csv: the batches holding stock, the month as YYYY-MM'
);
select results_eq(
  $$select date, type, product, delta, before, after, "user", reference, reason, note
    from public.export_transactions('00000000-0000-4000-8000-000000018411')$$,
  $$values
    ('2026-10-01 09:00', 'Receiving', 'Septocaine 4% "épi"', 40.00::numeric, 0.00::numeric, 40.00::numeric,
     'Sarah Mitchell', 'Patterson INV-10092', null::text, null::text),
    ('2026-10-02 10:30', 'Adjustment', 'Septocaine 4% "épi"', -10.00::numeric, 40.00::numeric, 30.00::numeric,
     'Michael Reyes', 'Manual', 'Damaged', 'Dropped, "cracked"')$$,
  'transactions.csv: the ledger oldest first at the clinic''s time, with who and why'
);
select is((select count(*)::integer from storage.buckets where id = 'exports' and public = false), 1,
  'the exports bucket is private');
select is((select count(*)::integer from pg_policies where tablename = 'objects' and policyname like '%export%'), 0,
  'and no member policy opens it');
select is((select count(*)::integer from public.export_products('00000000-0000-4000-8000-0000000184ff')), 0,
  'another clinic''s id reads nothing');
select is(
  (select jsonb_build_array(jsonb_array_length(d->'products'), jsonb_array_length(d->'batches'),
          jsonb_array_length(d->'transactions'), d->'products'->1->>'name', d->'transactions'->1->>'user')
   from public.export_data('00000000-0000-4000-8000-000000018411') d),
  '[2, 1, 2, "Old cement", "Michael Reyes"]'::jsonb,
  'export_data: the three files in one value, in their order'
);

select * from finish();
rollback;
