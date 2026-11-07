-- No alerts before a product's first stock (20261107063703_no_alerts_before_first_stock.sql): a product never stocked
-- reads Out of stock but gets no Out of stock or Low alert, no push and no automatic To buy line, from the nightly
-- refresh, a level change, a clinic setting, a procedure that finds none or a count that finds none; its first count,
-- adjustment or delivery brings them back as before; a product once stocked and used down to 0 raises them as before.
begin;
select plan(29);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000051a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000051a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-000000051c01', 'Smile Groove', 'CA', 'CAD', 'America/Toronto', '{90}');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000051c01', '00000000-0000-4000-8000-000000051a01', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000051c01', '00000000-0000-4000-8000-000000051a02', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active');
-- As a starting catalog or New product leaves them: every product at 0, none ever stocked. The pens also carry the
-- Out of stock alert the nightly refresh gave such a product before this rule.
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target) values
  ('00000000-0000-4000-8000-000000051d01', '00000000-0000-4000-8000-000000051c01', 'Septocaine', 'cartridges', 'countable', 20, 60),
  ('00000000-0000-4000-8000-000000051d02', '00000000-0000-4000-8000-000000051c01', 'Nitrile gloves M', 'boxes', 'countable', 4, 12),
  ('00000000-0000-4000-8000-000000051d03', '00000000-0000-4000-8000-000000051c01', 'Bonding agent', 'bottles', 'multi_use', 1, 3),
  ('00000000-0000-4000-8000-000000051d04', '00000000-0000-4000-8000-000000051c01', 'Gauze', 'packs', 'countable', 5, 10),
  ('00000000-0000-4000-8000-000000051d05', '00000000-0000-4000-8000-000000051c01', 'Pens', 'pens', 'countable', 2, 10);
insert into public.alerts (id, clinic_id, kind, product_id) values
  ('00000000-0000-4000-8000-000000051e05', '00000000-0000-4000-8000-000000051c01', 'out_of_stock', '00000000-0000-4000-8000-000000051d05');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.k(n int) returns uuid language sql as $$ select ('00000000-0000-4000-8000-0000000511' || lpad(n::text, 2, '0'))::uuid $$;
-- What a product's stock alerts, pushes and automatic To buy lines are, as one line: kinds of open alerts, kinds of
-- queued pushes, the quantity of its automatic line still to buy.
create function pg_temp.raised(p uuid) returns text language sql as $$
  select concat_ws(' · ',
    'alerts ' || coalesce((select string_agg(kind::text, ',' order by kind::text) from public.alerts
                           where product_id = p and resolved_at is null and kind in ('out_of_stock', 'low')), 'none'),
    'pushes ' || coalesce((select string_agg(kind::text, ',' order by kind::text) from public.push_outbox
                           where product_id = p and kind = 'out_of_stock'
                             and alert_id in (select id from public.alerts where resolved_at is null)), 'none'),
    'to buy ' || coalesce((select qty::integer::text from public.to_buy_items
                           where product_id = p and source = 'auto' and status = 'to_buy'), 'none'))
$$;

-- Never stocked: Out of stock, and nothing raised -------------------------------------------------------------------------
select is((select status from public.product_status where product_id = '00000000-0000-4000-8000-000000051d01'), 'out_of_stock',
  'a product never stocked reads Out of stock');
select ok(public.refresh_all_products() >= 5, 'the nightly refresh visits every product, these five among them');
select is(pg_temp.raised('00000000-0000-4000-8000-000000051d01'), 'alerts none · pushes none · to buy none',
  'and gives Septocaine, never stocked, no alert, no push and no To buy line');
select is(
  (select count(*) from public.alerts where clinic_id = '00000000-0000-4000-8000-000000051c01' and resolved_at is null),
  0::bigint, 'nor any other product of the clinic');
select is(
  (select count(*) from public.to_buy_items where clinic_id = '00000000-0000-4000-8000-000000051c01'),
  0::bigint, 'and To buy stays empty');
select isnt((select resolved_at from public.alerts where id = '00000000-0000-4000-8000-000000051e05'), null,
  'the Out of stock alert the pens had from before closes, so its push is not sent');

select pg_temp.act_as('00000000-0000-4000-8000-000000051a01');
update public.products set minimum = 30, target = 90 where id = '00000000-0000-4000-8000-000000051d01';
select public.clinic_settings_save('00000000-0000-4000-8000-000000051c01', 'Smile Groove', null, 'CA', 'CAD',
  'America/Toronto', '{30,60,90}', true);
reset role;
select is(pg_temp.raised('00000000-0000-4000-8000-000000051d01'), 'alerts none · pushes none · to buy none',
  'a new minimum and target, and a new expiry warning that refreshes every product, raise nothing either');

select pg_temp.act_as('00000000-0000-4000-8000-000000051a02');
select public.stock_procedure_start('00000000-0000-4000-8000-000000051c01', null, 'Filling',
  '[{"product_id":"00000000-0000-4000-8000-000000051d01","qty":2}]', '{}'::uuid[], pg_temp.k(1));
select public.stock_count_apply('00000000-0000-4000-8000-000000051c01',
  '[{"product_id":"00000000-0000-4000-8000-000000051d04","counted":0}]', pg_temp.k(2));
reset role;
select is((select count(*) from public.transactions where product_id = '00000000-0000-4000-8000-000000051d01'), 0::bigint,
  'a procedure that uses 2 Septocaine finds none, so nothing leaves stock and no ledger row is written');
select is(pg_temp.raised('00000000-0000-4000-8000-000000051d01'), 'alerts none · pushes none · to buy none',
  'so Septocaine stays quiet');
select is(pg_temp.raised('00000000-0000-4000-8000-000000051d04'), 'alerts none · pushes none · to buy none',
  'and a count that finds no Gauze moves nothing, so Gauze stays quiet too');

select pg_temp.act_as('00000000-0000-4000-8000-000000051a02');
select public.to_buy_add('00000000-0000-4000-8000-000000051c01', '00000000-0000-4000-8000-000000051d05');
reset role;
select results_eq(
  $$ select source::text, status::text, qty from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000051d05' $$,
  $$ values ('manual', 'to_buy', 10::numeric) $$,
  'Add to buy still puts a product never stocked on the list, for its target');

-- The first count, adjustment or delivery brings the rule back --------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000051a02');
select public.stock_count_apply('00000000-0000-4000-8000-000000051c01',
  '[{"product_id":"00000000-0000-4000-8000-000000051d01","counted":10}]', pg_temp.k(3));
reset role;
select is((select status from public.product_status where product_id = '00000000-0000-4000-8000-000000051d01'), 'low',
  'Septocaine''s first count finds 10, at or under its minimum of 30');
select is(pg_temp.raised('00000000-0000-4000-8000-000000051d01'), 'alerts low · pushes none · to buy 80',
  'which opens its Low alert and its automatic To buy line for 90 − 10, as before (Low pushes nothing)');

select pg_temp.act_as('00000000-0000-4000-8000-000000051a02');
select public.stock_adjust('00000000-0000-4000-8000-000000051d03', 1, 'Physical count', null, pg_temp.k(4));
reset role;
select is((select status from public.product_status where product_id = '00000000-0000-4000-8000-000000051d03'), 'low',
  'the first adjustment of Bonding agent sets 1 unopened, at its minimum of 1');
select is(pg_temp.raised('00000000-0000-4000-8000-000000051d03'), 'alerts low · pushes none · to buy 2',
  'which opens its Low alert and its automatic To buy line for 3 − 1');

select pg_temp.act_as('00000000-0000-4000-8000-000000051a01');
select public.stock_receive('00000000-0000-4000-8000-000000051c01',
  jsonb_build_array(jsonb_build_object('product_id', '00000000-0000-4000-8000-000000051d04', 'qty', 3,
    'expiry_month', date_trunc('month', current_date + interval '2 years')::date)), pg_temp.k(5));
reset role;
select is((select status from public.product_status where product_id = '00000000-0000-4000-8000-000000051d04'), 'low',
  'the first delivery of Gauze brings 3, under its minimum of 5');
select is(pg_temp.raised('00000000-0000-4000-8000-000000051d04'), 'alerts low · pushes none · to buy 7',
  'which opens its Low alert and its automatic To buy line for 10 − 3');

select pg_temp.act_as('00000000-0000-4000-8000-000000051a02');
select public.stock_procedure_start('00000000-0000-4000-8000-000000051c01', null, 'Extraction',
  '[{"product_id":"00000000-0000-4000-8000-000000051d01","qty":10}]', '{}'::uuid[], pg_temp.k(6));
reset role;
select is((select status from public.product_status where product_id = '00000000-0000-4000-8000-000000051d01'), 'out_of_stock',
  'a procedure then uses Septocaine''s 10');
select is(pg_temp.raised('00000000-0000-4000-8000-000000051d01'), 'alerts out_of_stock · pushes out_of_stock · to buy 90',
  'which opens its Out of stock alert in place of Low, queues its push and raises its line to 90 − 0');
select is(
  (select count(*) from public.alerts where product_id = '00000000-0000-4000-8000-000000051d01' and kind = 'low' and resolved_at is not null),
  1::bigint, 'the Low alert closed as it went out');

-- Once stocked, used down to 0: as before ----------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000051a01');
select public.stock_receive('00000000-0000-4000-8000-000000051c01',
  jsonb_build_array(jsonb_build_object('product_id', '00000000-0000-4000-8000-000000051d02', 'qty', 6,
    'expiry_month', date_trunc('month', current_date + interval '2 years')::date)), pg_temp.k(7));
reset role;
select is((select status from public.product_status where product_id = '00000000-0000-4000-8000-000000051d02'), 'healthy',
  'six boxes of gloves arrive, above their minimum of 4');
select is(pg_temp.raised('00000000-0000-4000-8000-000000051d02'), 'alerts none · pushes none · to buy none',
  'so nothing is raised for them');
select pg_temp.act_as('00000000-0000-4000-8000-000000051a02');
select public.stock_count_apply('00000000-0000-4000-8000-000000051c01',
  '[{"product_id":"00000000-0000-4000-8000-000000051d02","counted":0}]', pg_temp.k(8));
reset role;
select is((select status from public.product_status where product_id = '00000000-0000-4000-8000-000000051d02'), 'out_of_stock',
  'a count later finds none left');
select is(pg_temp.raised('00000000-0000-4000-8000-000000051d02'), 'alerts out_of_stock · pushes out_of_stock · to buy 12',
  'which opens their Out of stock alert, queues its push and adds their line for 12, as before');
select ok(public.refresh_all_products() >= 5, 'the next nightly refresh visits them all again');
select is(pg_temp.raised('00000000-0000-4000-8000-000000051d02'), 'alerts out_of_stock · pushes out_of_stock · to buy 12',
  'and keeps the gloves'' alert, push and line, without a second of each');
select is(
  (select count(*) from public.alerts where product_id = '00000000-0000-4000-8000-000000051d02' and kind = 'out_of_stock'),
  1::bigint, 'one Out of stock alert for the gloves in all');
select is(pg_temp.raised('00000000-0000-4000-8000-000000051d05'), 'alerts none · pushes none · to buy none',
  'while the pens, never stocked, stay quiet on that refresh too (their line is the one added by hand)');
select is((select status from public.product_status where product_id = '00000000-0000-4000-8000-000000051d05'), 'out_of_stock',
  'and still read Out of stock');


select * from finish();
rollback;
