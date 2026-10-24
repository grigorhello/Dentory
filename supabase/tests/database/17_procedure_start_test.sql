-- MS-123 · procedure_template_detail, and starting a procedure the way Adjust, then start sends it.
begin;
select plan(20);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000000b31', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000000b32', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000000b33', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-000000000b41', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', '{90}'),
  ('00000000-0000-4000-8000-000000000b42', 'Other Dental', 'CA', 'CAD', 'America/Toronto', '{90}');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b31', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b32', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000000b42', '00000000-0000-4000-8000-000000000b33', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
-- Septocaine 54 cartridges, Rubber dam none left, Surface disinfectant 1 unopened and 1 open, Old gauze archived.
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target, archived_at) values
  ('00000000-0000-4000-8000-000000000b61', '00000000-0000-4000-8000-000000000b41', 'Septocaine', 'cartridges', 'countable', 20, 60, null),
  ('00000000-0000-4000-8000-000000000b62', '00000000-0000-4000-8000-000000000b41', 'Rubber dam', 'sheets', 'countable', 10, 36, null),
  ('00000000-0000-4000-8000-000000000b63', '00000000-0000-4000-8000-000000000b41', 'Surface disinfectant', 'bottles', 'multi_use', 0, 4, null),
  ('00000000-0000-4000-8000-000000000b64', '00000000-0000-4000-8000-000000000b41', 'Old gauze', 'packs', 'countable', 0, 2, now()),
  ('00000000-0000-4000-8000-000000000b65', '00000000-0000-4000-8000-000000000b42', 'Other clinic product', 'packs', 'countable', 0, 2, null);
insert into public.batches (clinic_id, product_id, expiry_month, qty) values
  ('00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b61', date_trunc('month', current_date + interval '10 months')::date, 54),
  ('00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b63', date_trunc('month', current_date + interval '10 months')::date, 1),
  ('00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b64', null, 5);
insert into public.open_items (clinic_id, product_id, opened_by, opened_at) values
  ('00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b63', '00000000-0000-4000-8000-000000000b31', now() - interval '3 days');
insert into public.procedure_templates (id, clinic_id, name, archived_at) values
  ('00000000-0000-4000-8000-000000000b71', '00000000-0000-4000-8000-000000000b41', 'Root canal', null),
  ('00000000-0000-4000-8000-000000000b72', '00000000-0000-4000-8000-000000000b41', 'Retired', now()),
  ('00000000-0000-4000-8000-000000000b73', '00000000-0000-4000-8000-000000000b42', 'Other clinic template', null);
insert into public.procedure_template_items (clinic_id, template_id, product_id, default_qty, position) values
  ('00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b71', '00000000-0000-4000-8000-000000000b63', 0, 4),
  ('00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b71', '00000000-0000-4000-8000-000000000b61', 2, 1),
  ('00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b71', '00000000-0000-4000-8000-000000000b62', 1, 2),
  ('00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b71', '00000000-0000-4000-8000-000000000b64', 1, 3);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.detail(p uuid) returns jsonb language sql as $$ select public.procedure_template_detail(p) $$;

select ok(not has_function_privilege('anon', 'public.procedure_template_detail(uuid)', 'execute'), 'anon cannot read a template');
select ok(has_function_privilege('authenticated', 'public.procedure_template_detail(uuid)', 'execute'), 'members can');

select pg_temp.act_as('00000000-0000-4000-8000-000000000b32');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000b71') ->> 'name', 'Root canal', 'staff read the template with its name');
select results_eq(
  $$ select i ->> 'name', i ->> 'tracking', (i ->> 'default_qty')::numeric, (i ->> 'quantity')::numeric,
            (i ->> 'unopened')::numeric, (i ->> 'open_count')::integer
     from jsonb_array_elements(pg_temp.detail('00000000-0000-4000-8000-000000000b71') -> 'items') i $$,
  $$ values ('Septocaine', 'countable', 2::numeric, 54::numeric, 54::numeric, 0),
            ('Rubber dam', 'countable', 1::numeric, 0::numeric, 0::numeric, 0),
            ('Surface disinfectant', 'multi_use', 0::numeric, 2::numeric, 1::numeric, 1) $$,
  'the supplies come in the template''s order with the stock each takes from; archived products are left out');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000b72'), null, 'an archived template has no detail');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000b73'), null, 'nor has another clinic''s');
select is(pg_temp.detail('00000000-0000-4000-8000-0000000000ff'), null, 'nor one that does not exist');

-- What the app sends for f13 with one more Septocaine, Rubber dam short and Surface disinfectant taken new.
select lives_ok($$
  select public.stock_procedure_start(
    '00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b71', 'Root canal',
    '[{"product_id":"00000000-0000-4000-8000-000000000b61","qty":3},
      {"product_id":"00000000-0000-4000-8000-000000000b62","qty":1},
      {"product_id":"00000000-0000-4000-8000-000000000b63","qty":0}]',
    array['00000000-0000-4000-8000-000000000b63']::uuid[],
    '00000000-0000-4000-8000-000000000ba1')
$$, 'staff start the procedure');
select results_eq(
  $$ select name, started_by_name, item_count, cancelled_at is null from public.procedure_history('00000000-0000-4000-8000-000000000b41') $$,
  $$ values ('Root canal', 'Michael Reyes', 3, true) $$,
  'the procedure heads the history with Michael and its three supplies');
select results_eq(
  $$ select name, quantity, status from public.inventory_list('00000000-0000-4000-8000-000000000b41') where name <> 'Surface disinfectant' order by name $$,
  $$ values ('Rubber dam', -1::numeric, 'out_of_stock'), ('Septocaine', 51::numeric, 'healthy') $$,
  'the short item goes negative and reads Out of stock; nothing was blocked');
select results_eq(
  $$ select unopened, open_count from public.inventory_list('00000000-0000-4000-8000-000000000b41') where name = 'Surface disinfectant' $$,
  $$ values (0::numeric, 2) $$,
  'Take new moved one unopened bottle to an open one');
select is(
  (select count(*) from public.open_items
   where product_id = '00000000-0000-4000-8000-000000000b63' and finished_at is null
     and opened_by = '00000000-0000-4000-8000-000000000b32' and opened_at::date = current_date),
  1::bigint, 'the new bottle is tagged with Michael and today');
select is(
  (select count(*) from public.procedure_event_openings o join public.procedure_events e on e.id = o.event_id
   where e.name = 'Root canal' and o.product_id = '00000000-0000-4000-8000-000000000b63'),
  1::bigint, 'and belongs to the procedure, so a cancellation can reverse it');
select results_eq(
  $$ select qty, source::text, status::text from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000000b62' $$,
  $$ values (37::numeric, 'auto', 'to_buy') $$,
  'To buy adds the short item by itself, up to its target');
select is(
  (select sum(delta) from public.transactions where product_id = '00000000-0000-4000-8000-000000000b61' and type = 'procedure'),
  -3::numeric, 'Septocaine records the three used');
select lives_ok($$
  select public.stock_procedure_start(
    '00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b71', 'Root canal',
    '[{"product_id":"00000000-0000-4000-8000-000000000b61","qty":3}]', '{}'::uuid[],
    '00000000-0000-4000-8000-000000000ba1')
$$, 'a replay of the queued start is accepted');
select is((select count(*) from public.procedure_events where clinic_id = '00000000-0000-4000-8000-000000000b41'), 1::bigint,
  'and records nothing twice');
select throws_ok($$
  select public.stock_procedure_start(
    '00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b71', 'Root canal',
    '[{"product_id":"00000000-0000-4000-8000-000000000b65","qty":1}]', '{}'::uuid[],
    '00000000-0000-4000-8000-000000000ba2')
$$, '42501', null, 'another clinic''s product cannot be used');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000b33');
select is(pg_temp.detail('00000000-0000-4000-8000-000000000b71'), null, 'Other Dental cannot read Smile Dental''s template');
select throws_ok($$
  select public.stock_procedure_start(
    '00000000-0000-4000-8000-000000000b41', '00000000-0000-4000-8000-000000000b71', 'Root canal',
    '[{"product_id":"00000000-0000-4000-8000-000000000b61","qty":1}]', '{}'::uuid[],
    '00000000-0000-4000-8000-000000000ba3')
$$, '42501', null, 'nor start a procedure there');
reset role;

select * from finish();
rollback;
