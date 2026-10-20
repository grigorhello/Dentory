-- MS-125 · procedure_template_save and procedure_template_archive: Save and Delete procedure on Edit procedure.
begin;
select plan(28);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000000c31', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000000c32', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000000c33', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-000000000c41', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', '{90}'),
  ('00000000-0000-4000-8000-000000000c42', 'Other Dental', 'CA', 'CAD', 'America/Toronto', '{90}');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c31', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c32', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000000c42', '00000000-0000-4000-8000-000000000c33', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target, archived_at) values
  ('00000000-0000-4000-8000-000000000c61', '00000000-0000-4000-8000-000000000c41', 'Septocaine', 'cartridges', 'countable', 20, 60, null),
  ('00000000-0000-4000-8000-000000000c62', '00000000-0000-4000-8000-000000000c41', 'Rubber dam', 'sheets', 'countable', 10, 36, null),
  ('00000000-0000-4000-8000-000000000c63', '00000000-0000-4000-8000-000000000c41', 'Surface disinfectant', 'bottles', 'multi_use', 0, 4, null),
  ('00000000-0000-4000-8000-000000000c64', '00000000-0000-4000-8000-000000000c41', 'Old gauze', 'packs', 'countable', 0, 2, now()),
  ('00000000-0000-4000-8000-000000000c65', '00000000-0000-4000-8000-000000000c42', 'Other clinic product', 'packs', 'countable', 0, 2, null);
insert into public.batches (clinic_id, product_id, expiry_month, qty) values
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c61', null, 54),
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c62', null, 20);
insert into public.procedure_templates (id, clinic_id, name) values
  ('00000000-0000-4000-8000-000000000c71', '00000000-0000-4000-8000-000000000c41', 'Root canal'),
  ('00000000-0000-4000-8000-000000000c72', '00000000-0000-4000-8000-000000000c41', 'Filling'),
  ('00000000-0000-4000-8000-000000000c74', '00000000-0000-4000-8000-000000000c41', 'Crown prep'),
  ('00000000-0000-4000-8000-000000000c73', '00000000-0000-4000-8000-000000000c42', 'Other clinic template');
insert into public.procedure_template_items (clinic_id, template_id, product_id, default_qty, position) values
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c71', '00000000-0000-4000-8000-000000000c61', 2, 1),
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c71', '00000000-0000-4000-8000-000000000c62', 1, 2),
  ('00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c71', '00000000-0000-4000-8000-000000000c63', 0, 3);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.save(p_template uuid, p_name text, p_items jsonb) returns jsonb language sql as $$
  select public.procedure_template_save('00000000-0000-4000-8000-000000000c41', p_template, p_name, p_items) - 'id'
$$;

select ok(not has_function_privilege('anon', 'public.procedure_template_save(uuid, uuid, text, jsonb)', 'execute'),
  'anon cannot save a template');
select ok(not has_function_privilege('anon', 'public.procedure_template_archive(uuid)', 'execute'), 'nor delete one');

-- Michael (Staff) performs a Root canal, then tries the admin functions directly.
select pg_temp.act_as('00000000-0000-4000-8000-000000000c32');
select lives_ok($$
  select public.stock_procedure_start(
    '00000000-0000-4000-8000-000000000c41', '00000000-0000-4000-8000-000000000c71', 'Root canal',
    '[{"product_id":"00000000-0000-4000-8000-000000000c61","qty":2},
      {"product_id":"00000000-0000-4000-8000-000000000c62","qty":1},
      {"product_id":"00000000-0000-4000-8000-000000000c63","qty":0}]',
    '{}'::uuid[], '00000000-0000-4000-8000-000000000ca1')
$$, 'staff perform a Root canal');
select throws_ok($$ select pg_temp.save('00000000-0000-4000-8000-000000000c71', 'Root canal', '[]') $$,
  '42501', 'Only an admin can edit procedures', 'staff calling the save directly are refused');
select throws_ok($$ select pg_temp.save(null, 'Extraction', '[]') $$,
  '42501', 'Only an admin can edit procedures', 'and cannot create a template');
select throws_ok($$ select public.procedure_template_archive('00000000-0000-4000-8000-000000000c71') $$,
  '42501', 'Only an admin can delete procedures', 'nor delete one');
reset role;

-- Sarah (Admin) edits Root canal: renamed, reordered, Rubber dam up to 3, the multi-use product sent with 1, and
-- a product archived while the screen was open.
select pg_temp.act_as('00000000-0000-4000-8000-000000000c31');
select is(
  pg_temp.save('00000000-0000-4000-8000-000000000c71', '  Root canal treatment ',
    '[{"product_id":"00000000-0000-4000-8000-000000000c62","default_qty":3},
      {"product_id":"00000000-0000-4000-8000-000000000c61","default_qty":2},
      {"product_id":"00000000-0000-4000-8000-000000000c63","default_qty":1},
      {"product_id":"00000000-0000-4000-8000-000000000c64","default_qty":1}]'),
  '{"name": "Root canal treatment", "item_count": 3}'::jsonb,
  'the admin saves Root canal under its new name with three supplies');
select results_eq(
  $$ select p.name, i.default_qty, i.position from public.procedure_template_items i
     join public.products p on p.id = i.product_id
     where i.template_id = '00000000-0000-4000-8000-000000000c71' order by i.position $$,
  $$ values ('Rubber dam', 3::numeric, 1), ('Septocaine', 2::numeric, 2), ('Surface disinfectant', 0::numeric, 3) $$,
  'the supplies follow the screen order, the multi-use one stays at 0 and the archived one is left out');
select results_eq(
  $$ select e.name, p.name, i.qty from public.procedure_events e
     join public.procedure_event_items i on i.event_id = e.id
     join public.products p on p.id = i.product_id
     where e.template_id = '00000000-0000-4000-8000-000000000c71' order by p.name $$,
  $$ values ('Root canal', 'Rubber dam', 1::numeric), ('Root canal', 'Septocaine', 2::numeric),
            ('Root canal', 'Surface disinfectant', 0::numeric) $$,
  'editing the defaults never changes the procedure performed before');
select lives_ok($$
  select pg_temp.save('00000000-0000-4000-8000-000000000c71', 'root canal treatment',
    '[{"product_id":"00000000-0000-4000-8000-000000000c62","default_qty":3}]')
$$, 'a template keeps its own name in another case');
select is(pg_temp.save(null, '   ', '[]'), '{"name": "Untitled procedure", "item_count": 0}'::jsonb,
  'a new procedure without a name is saved as Untitled procedure');
select throws_ok($$ select pg_temp.save(null, '', '[]') $$,
  '22023', 'Another procedure is already called Untitled procedure.', 'a second one asks for another name');
select throws_ok($$ select pg_temp.save('00000000-0000-4000-8000-000000000c71', 'FILLING', '[]') $$,
  '22023', 'Another procedure is already called Filling.', 'names are unique among active templates, in any case');
select throws_ok($$ select pg_temp.save(null, repeat('a', 121), '[]') $$,
  '22023', 'Use 120 characters or fewer for the name.', 'a name of more than 120 characters is refused');
select throws_ok($$
  select pg_temp.save('00000000-0000-4000-8000-000000000c71', 'Root canal',
    '[{"product_id":"00000000-0000-4000-8000-000000000c61","default_qty":0}]')
$$, '22023', 'Set at least 1 for Septocaine.', 'a countable supply needs a default of at least 1');
select throws_ok($$
  select pg_temp.save('00000000-0000-4000-8000-000000000c71', 'Root canal',
    '[{"product_id":"00000000-0000-4000-8000-000000000c61","default_qty":1},
      {"product_id":"00000000-0000-4000-8000-000000000c61","default_qty":2}]')
$$, '22023', 'Septocaine is on the list twice.', 'a product is listed once');
select throws_ok($$
  select pg_temp.save('00000000-0000-4000-8000-000000000c71', 'Root canal',
    '[{"product_id":"00000000-0000-4000-8000-000000000c65","default_qty":1}]')
$$, '22023', 'A supply on the list is not a product of this clinic.', 'another clinic''s product is refused');
select throws_ok($$ select pg_temp.save('00000000-0000-4000-8000-000000000c73', 'Taken over', '[]') $$,
  '22023', 'This procedure no longer exists.', 'another clinic''s template cannot be saved over');
select throws_ok($$ select pg_temp.save('00000000-0000-4000-8000-0000000000ff', 'Ghost', '[]') $$,
  '22023', 'This procedure no longer exists.', 'nor one that does not exist');
select is(
  (select name from public.procedure_templates where id = '00000000-0000-4000-8000-000000000c71'),
  'root canal treatment', 'a refused save leaves the template as it was');

-- Delete procedure.
select lives_ok($$ select public.procedure_template_archive('00000000-0000-4000-8000-000000000c71') $$,
  'the admin deletes Root canal treatment');
select lives_ok($$ select public.procedure_template_archive('00000000-0000-4000-8000-000000000c71') $$,
  'deleting it again changes nothing');
select results_eq(
  $$ select name from public.procedure_templates_list('00000000-0000-4000-8000-000000000c41') order by name $$,
  $$ values ('Crown prep'), ('Filling'), ('Untitled procedure') $$,
  'it leaves the Procedures list');
select results_eq(
  $$ select name, item_count from public.procedure_history('00000000-0000-4000-8000-000000000c41') $$,
  $$ values ('Root canal', 3) $$,
  'the procedure performed from it keeps its data');
select is(pg_temp.save(null, 'Root canal treatment', '[]'), '{"name": "Root canal treatment", "item_count": 0}'::jsonb,
  'its name can be used again');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000c33');
select throws_ok($$ select public.procedure_template_archive('00000000-0000-4000-8000-000000000c74') $$,
  '22023', 'This procedure no longer exists.', 'another clinic''s admin cannot see Crown prep to delete it');
reset role;

update public.clinics set subscription_status = 'read_only' where id = '00000000-0000-4000-8000-000000000c41';
select pg_temp.act_as('00000000-0000-4000-8000-000000000c31');
select throws_ok($$ select pg_temp.save('00000000-0000-4000-8000-000000000c74', 'Crown prep', '[]') $$,
  '42501', 'The clinic is read-only until a payment method is added', 'a read-only clinic cannot save');
select throws_ok($$ select public.procedure_template_archive('00000000-0000-4000-8000-000000000c74') $$,
  '42501', 'The clinic is read-only until a payment method is added', 'nor delete');
reset role;

select * from finish();
rollback;
