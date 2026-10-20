-- MS-132 · expiring_batches: the batches expiring within a window, expired first, with their value, clinic-isolated;
-- disposing a whole batch takes it off the list and off Home's figures, and Undo brings it back.
begin;
select plan(19);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000000f31', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000000f32', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000000f33', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-000000000f41', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', '{30,60,90}'),
  ('00000000-0000-4000-8000-000000000f42', 'Other Dental', 'CA', 'CAD', 'America/Toronto', '{90}');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f31', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f32', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000000f42', '00000000-0000-4000-8000-000000000f33', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target, last_unit_cost) values
  ('00000000-0000-4000-8000-000000000f61', '00000000-0000-4000-8000-000000000f41', 'Septocaine 4% 1:100,000', 'cartridges', 'countable', 20, 60, 3.06),
  ('00000000-0000-4000-8000-000000000f62', '00000000-0000-4000-8000-000000000f41', 'Bonding agent', 'bottles', 'multi_use', 1, 3, 82),
  ('00000000-0000-4000-8000-000000000f63', '00000000-0000-4000-8000-000000000f41', 'Etch gel 37%', 'syringes', 'countable', 1, 4, 5),
  ('00000000-0000-4000-8000-000000000f64', '00000000-0000-4000-8000-000000000f41', 'Composite A2', 'syringes', 'countable', 1, 6, null),
  ('00000000-0000-4000-8000-000000000f65', '00000000-0000-4000-8000-000000000f42', 'Other clinic product', 'packs', 'countable', 0, 1, 1);
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target, last_unit_cost, archived_at) values
  ('00000000-0000-4000-8000-000000000f66', '00000000-0000-4000-8000-000000000f41', 'Old gauze', 'packs', 'countable', 5, 10, 1, now());
-- Etch gel expired last month; Bonding agent expires this month; Septocaine next month (lot B441) and in four
-- months (A112, outside every window); Composite next month with no unit cost; plus a spent batch, an undated
-- one, an archived product's and another clinic's, none of which may show.
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000000f71', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f63', date_trunc('month', current_date - interval '1 month')::date, 'E2', 3),
  ('00000000-0000-4000-8000-000000000f72', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f62', date_trunc('month', current_date)::date, 'BA7', 1),
  ('00000000-0000-4000-8000-000000000f73', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f61', date_trunc('month', current_date + interval '1 month')::date, 'B441', 34),
  ('00000000-0000-4000-8000-000000000f74', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f61', date_trunc('month', current_date + interval '4 months')::date, 'A112', 20),
  ('00000000-0000-4000-8000-000000000f75', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f64', date_trunc('month', current_date + interval '1 month')::date, null, 2),
  ('00000000-0000-4000-8000-000000000f76', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f61', date_trunc('month', current_date)::date, 'Z0', 0),
  ('00000000-0000-4000-8000-000000000f77', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f61', null, null, 4),
  ('00000000-0000-4000-8000-000000000f78', '00000000-0000-4000-8000-000000000f41', '00000000-0000-4000-8000-000000000f66', date_trunc('month', current_date)::date, 'G1', 5),
  ('00000000-0000-4000-8000-000000000f79', '00000000-0000-4000-8000-000000000f42', '00000000-0000-4000-8000-000000000f65', date_trunc('month', current_date)::date, 'O1', 1);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.lots(p_window integer default null) returns text[] language sql as $$
  select coalesce(array_agg(coalesce(b ->> 'lot', '—') order by ord), '{}')
  from jsonb_array_elements(public.expiring_batches('00000000-0000-4000-8000-000000000f41', p_window) -> 'batches')
    with ordinality as x(b, ord)
$$;
create function pg_temp.days(p_batch uuid) returns integer language sql as $$
  select public.days_to_expiry(expiry_month, 'America/Toronto') from public.batches where id = p_batch
$$;

select ok(not has_function_privilege('anon', 'public.expiring_batches(uuid, integer)', 'execute'), 'anon cannot read expiring batches');
select ok(has_function_privilege('authenticated', 'public.expiring_batches(uuid, integer)', 'execute'), 'members can');

select pg_temp.act_as('00000000-0000-4000-8000-000000000f32');
select is((public.expiring_batches('00000000-0000-4000-8000-000000000f41') ->> 'window')::integer, 90,
  'with no window the clinic''s largest threshold applies');
select is(pg_temp.lots(), array['E2', 'BA7', '—', 'B441'],
  'Staff see the expired batch first, then this month, then next month by name; spent, undated, archived and far-off batches stay out');
select is((public.expiring_batches('00000000-0000-4000-8000-000000000f41', 30) ->> 'window')::integer, 30, 'a window can be asked for');
select is(pg_temp.lots(30), array['E2', 'BA7'] || case when pg_temp.days('00000000-0000-4000-8000-000000000f73') <= 30 then array['—', 'B441'] else '{}' end,
  'the 30-day window keeps what expires within 30 days, the expired batch included');
select is(pg_temp.lots(pg_temp.days('00000000-0000-4000-8000-000000000f73')), array['E2', 'BA7', '—', 'B441'],
  'a batch is in the window when its days left equal the window');
select is(pg_temp.lots(pg_temp.days('00000000-0000-4000-8000-000000000f73') - 1), array['E2', 'BA7'],
  'and out of it one day earlier');
select results_eq(
  $$ select b ->> 'name', b ->> 'unit', b ->> 'tracking', (b ->> 'qty')::numeric, (b ->> 'value')::numeric
     from jsonb_array_elements(public.expiring_batches('00000000-0000-4000-8000-000000000f41') -> 'batches') b $$,
  $$ values ('Etch gel 37%', 'syringes', 'countable', 3::numeric, 15::numeric),
            ('Bonding agent', 'bottles', 'multi_use', 1::numeric, 82::numeric),
            ('Composite A2', 'syringes', 'countable', 2::numeric, 0::numeric),
            ('Septocaine 4% 1:100,000', 'cartridges', 'countable', 34::numeric, 104.04::numeric) $$,
  'each batch carries its product, quantity and value at the last unit cost, 0 without one');
select is(public.expiring_batches('00000000-0000-4000-8000-000000000f41') -> 'batches' -> 3 ->> 'product_id', '00000000-0000-4000-8000-000000000f61',
  'and the product it opens');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000f33');
select is(public.expiring_batches('00000000-0000-4000-8000-000000000f41') -> 'batches', '[]'::jsonb, 'another clinic sees none of them');
select is(public.expiring_batches('00000000-0000-4000-8000-000000000f41') ->> 'window', null, 'nor the clinic''s window');
reset role;

-- Acceptance: disposing the whole batch removes it and updates Home's Expiring soon tile and value at risk.
select pg_temp.act_as('00000000-0000-4000-8000-000000000f31');
select results_eq(
  $$ select expiring_batch_count, value_at_risk_90 from public.clinic_attention where clinic_id = '00000000-0000-4000-8000-000000000f41' $$,
  $$ values (4, 201.04::numeric(14, 2)) $$, 'Home counts the four batches and $201.04 at risk');
select throws_ok($$ select public.stock_dispose('00000000-0000-4000-8000-000000000f73', 35, '00000000-0000-4000-8000-0000000002f1') $$,
  '22023', 'the disposed quantity must be between 0 and what the batch holds', 'no more than the batch holds');
select lives_ok($$ select public.stock_dispose('00000000-0000-4000-8000-000000000f73', 34, '00000000-0000-4000-8000-0000000002f2') $$,
  'the admin disposes the whole Septocaine batch');
select is(pg_temp.lots(), array['E2', 'BA7', '—'], 'the batch leaves Expiring soon');
select results_eq(
  $$ select expiring_batch_count, value_at_risk_90 from public.clinic_attention where clinic_id = '00000000-0000-4000-8000-000000000f41' $$,
  $$ values (3, 97::numeric(14, 2)) $$, 'and Home''s tile and value at risk drop with it');
select lives_ok($$ select public.undo_action((select id from public.stock_actions where idempotency_key = '00000000-0000-4000-8000-0000000002f2'), '00000000-0000-4000-8000-0000000002f3') $$,
  'Undo restores it');
select is(pg_temp.lots(), array['E2', 'BA7', '—', 'B441'], 'and the batch is back on Expiring soon');
reset role;

select * from finish();
rollback;
