-- Stock never goes below 0 (Grigor, 2026-11-07, in place of MS-100 D9's negative stock): no batch holds less than 0; a
-- procedure that uses more than is in stock still starts, stops at 0 and keeps what it used; Edit usage and Cancel give
-- back only what was taken; Take new opens only a bottle that is there; Undo keeps what was used since; and the one-time
-- repair of stock that went below 0 before.
begin;
select plan(48);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000050a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000050a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-000000050c01', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', '{90}');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050a01', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050a02', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active');
-- Pens none, Septocaine 7 in a batch expiring in 6 months, Bonding agent nothing unopened or open, Nitrile gloves 5
-- with no expiry.
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target) values
  ('00000000-0000-4000-8000-000000050d01', '00000000-0000-4000-8000-000000050c01', 'Pens', 'pens', 'countable', 2, 10),
  ('00000000-0000-4000-8000-000000050d02', '00000000-0000-4000-8000-000000050c01', 'Septocaine', 'cartridges', 'countable', 20, 60),
  ('00000000-0000-4000-8000-000000050d03', '00000000-0000-4000-8000-000000050c01', 'Bonding agent', 'bottles', 'multi_use', 1, 3),
  ('00000000-0000-4000-8000-000000050d04', '00000000-0000-4000-8000-000000050c01', 'Nitrile gloves M', 'boxes', 'countable', 3, 10);
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000050b02', '00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050d02',
   date_trunc('month', current_date + interval '6 months')::date, 'S1', 7),
  ('00000000-0000-4000-8000-000000050b04', '00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050d04', null, null, 5);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.qty(p uuid) returns numeric language sql as $$ select quantity from public.product_stock where product_id = p $$;
create function pg_temp.batch_qty(b uuid) returns numeric language sql as $$ select qty from public.batches where id = b $$;
create function pg_temp.k(n int) returns uuid language sql as $$ select ('00000000-0000-4000-8000-0000000501' || lpad(n::text, 2, '0'))::uuid $$;
create function pg_temp.action(n int) returns uuid language sql as $$ select id from public.stock_actions where idempotency_key = pg_temp.k(n) $$;

-- The table holds the rule ----------------------------------------------------------------------------------------------
select throws_ok($$
  insert into public.batches (clinic_id, product_id, qty)
  values ('00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050d01', -1)
$$, '23514', null, 'no batch may hold less than 0, the undated one included');
select throws_ok($$ update public.batches set qty = -1 where id = '00000000-0000-4000-8000-000000050b04' $$,
  '23514', null, 'nor be set below 0');

-- A procedure that uses more than is in stock (Grigor's pens) -------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000050a02');
select lives_ok($$
  select public.stock_procedure_start('00000000-0000-4000-8000-000000050c01', null, 'Filling',
    '[{"product_id":"00000000-0000-4000-8000-000000050d01","qty":1},
      {"product_id":"00000000-0000-4000-8000-000000050d02","qty":9}]', '{}'::uuid[], pg_temp.k(1))
$$, 'a procedure that uses 1 pen with none in stock and 9 Septocaine with 7 still starts');
select results_eq(
  $$ select name, quantity, status from public.inventory_list('00000000-0000-4000-8000-000000050c01')
     where name in ('Pens', 'Septocaine') order by name $$,
  $$ values ('Pens', 0::numeric, 'out_of_stock'), ('Septocaine', 0::numeric, 'out_of_stock') $$,
  'both stop at 0 and read Out of stock: the pens are not at -1');
select results_eq(
  $$ select p.name, i.qty from public.procedure_event_items i join public.products p on p.id = i.product_id
     where i.event_id = pg_temp.action(1) order by p.name $$,
  $$ values ('Pens', 1::numeric), ('Septocaine', 9::numeric) $$,
  'the procedure keeps what it used');
select is((select sum(delta) from public.transactions where product_id = '00000000-0000-4000-8000-000000050d02'), -7::numeric,
  'the ledger records the 7 Septocaine that left stock');
select is((select count(*) from public.transactions where product_id = '00000000-0000-4000-8000-000000050d01'), 0::bigint,
  'and nothing for the pens, since none left stock');
select is((select count(*) from public.batches where product_id = '00000000-0000-4000-8000-000000050d01'), 0::bigint,
  'nor does a batch appear for them');
select results_eq(
  $$ select p.name, t.qty from public.to_buy_items t join public.products p on p.id = t.product_id
     where t.status = 'to_buy' order by p.name $$,
  $$ values ('Pens', 10::numeric), ('Septocaine', 60::numeric) $$,
  'both go on To buy, up to their targets');

-- Edit usage gives back only what was taken -------------------------------------------------------------------------------
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000050a01');
select lives_ok($$ select public.stock_receive('00000000-0000-4000-8000-000000050c01',
  '[{"product_id":"00000000-0000-4000-8000-000000050d02","qty":20}]', pg_temp.k(2)) $$, 'Sarah receives 20 Septocaine with no expiry');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000050a02');
select lives_ok($$ select public.stock_procedure_edit(pg_temp.action(1),
  '[{"product_id":"00000000-0000-4000-8000-000000050d01","qty":1},{"product_id":"00000000-0000-4000-8000-000000050d02","qty":8}]',
  '{}'::uuid[], pg_temp.k(3)) $$, 'Septocaine used goes from 9 to 8');
select is(pg_temp.qty('00000000-0000-4000-8000-000000050d02'), 20::numeric,
  'nothing comes back: the 2 it used beyond the stock go first, and they never left it');
select lives_ok($$ select public.stock_procedure_edit(pg_temp.action(1),
  '[{"product_id":"00000000-0000-4000-8000-000000050d01","qty":0},{"product_id":"00000000-0000-4000-8000-000000050d02","qty":5}]',
  '{}'::uuid[], pg_temp.k(4)) $$, 'then from 8 to 5, and the pen from 1 to 0');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-000000050b02'), 2::numeric,
  'the 2 it took beyond 5 go back to the batch they came from');
select is(pg_temp.qty('00000000-0000-4000-8000-000000050d01'), 0::numeric, 'and the pen that never left stock gives nothing back');
select lives_ok($$ select public.stock_procedure_edit(pg_temp.action(1),
  '[{"product_id":"00000000-0000-4000-8000-000000050d02","qty":6}]',
  array['00000000-0000-4000-8000-000000050d03']::uuid[], pg_temp.k(5)) $$,
  'up from 5 to 6, with Bonding agent taken new though none is left');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-000000050b02'), 1::numeric, 'one more comes from the batch that expires first');
select is(pg_temp.qty('00000000-0000-4000-8000-000000050d02'), 21::numeric, 'Septocaine holds 21');
select is((select count(*) from public.open_items where product_id = '00000000-0000-4000-8000-000000050d03'), 0::bigint,
  'no bottle is opened out of nothing, and the edit still saves');
reset role;
select is(engine.procedure_taken(pg_temp.action(1), '00000000-0000-4000-8000-000000050d02'), 6::numeric,
  'the procedure has taken 6 Septocaine from stock');
select pg_temp.act_as('00000000-0000-4000-8000-000000050a02');

-- Cancel returns exactly what was taken -------------------------------------------------------------------------------------
select lives_ok($$ select public.stock_procedure_cancel(pg_temp.action(1), 'Logged by mistake', pg_temp.k(6)) $$, 'the Filling is cancelled');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-000000050b02'), 7::numeric, 'its 6 cartridges are back in their batch');
select is(pg_temp.qty('00000000-0000-4000-8000-000000050d02'), 27::numeric, 'and Septocaine holds 27, no more');
select lives_ok($$
  select public.stock_procedure_start('00000000-0000-4000-8000-000000050c01', null, 'Exam',
    '[{"product_id":"00000000-0000-4000-8000-000000050d01","qty":2}]', '{}'::uuid[], pg_temp.k(7))
$$, 'an Exam uses 2 pens with none in stock');
select lives_ok($$ select public.stock_procedure_cancel(pg_temp.action(7), 'Wrong patient chair', pg_temp.k(8)) $$, 'and is cancelled');
select is(pg_temp.qty('00000000-0000-4000-8000-000000050d01'), 0::numeric, 'the pens stay at 0: a cancel makes no stock out of nothing');

-- Take new opens only a bottle that is there --------------------------------------------------------------------------------
select lives_ok($$
  select public.stock_procedure_start('00000000-0000-4000-8000-000000050c01', null, 'Sealant', '[]',
    array['00000000-0000-4000-8000-000000050d03']::uuid[], pg_temp.k(9))
$$, 'a procedure taking new a bottle someone else took a moment before still starts');
select results_eq(
  $$ select unopened, open_count from public.product_stock where product_id = '00000000-0000-4000-8000-000000050d03' $$,
  $$ values (0::numeric, 0) $$,
  'and opens nothing, so nothing goes below 0');
reset role;
select throws_ok($$ select engine.open_one('00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050d03', null,
  'adjustment', 'manual', null, 'Opened a new bottle', gen_random_uuid()) $$,
  '22023', 'Bonding agent is out of stock.', 'no other path opens a bottle that is not there');

-- Undo keeps what was used since ------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-000000050a02');
select lives_ok($$ select public.stock_adjust('00000000-0000-4000-8000-000000050d04', 8, 'Returned', null, pg_temp.k(10)) $$,
  'Michael adjusts the gloves from 5 to 8');
select lives_ok($$
  select public.stock_procedure_start('00000000-0000-4000-8000-000000050c01', null, 'Crown',
    '[{"product_id":"00000000-0000-4000-8000-000000050d04","qty":6}]', '{}'::uuid[], pg_temp.k(11))
$$, 'and uses 6 in a Crown');
select throws_ok($$ select public.undo_action(pg_temp.action(10), pg_temp.k(12)) $$,
  '22023', 'Some of it was used already, so the adjustment stays.', 'so undoing the adjustment is refused');
select is(pg_temp.qty('00000000-0000-4000-8000-000000050d04'), 2::numeric, 'and the gloves hold the 2 left');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000050a01');
select lives_ok($$ select public.stock_receive('00000000-0000-4000-8000-000000050c01',
  '[{"product_id":"00000000-0000-4000-8000-000000050d01","qty":5}]', pg_temp.k(13)) $$, 'Sarah receives 5 pens');
select lives_ok($$
  select public.stock_procedure_start('00000000-0000-4000-8000-000000050c01', null, 'Exam',
    '[{"product_id":"00000000-0000-4000-8000-000000050d01","qty":4}]', '{}'::uuid[], pg_temp.k(14))
$$, 'and uses 4 of them');
select throws_ok($$ select public.undo_action(pg_temp.action(13), pg_temp.k(15)) $$,
  '22023', 'Some of this delivery was used already, so it stays received.', 'so the delivery stays received');
select lives_ok($$ select public.stock_receive('00000000-0000-4000-8000-000000050c01',
  '[{"product_id":"00000000-0000-4000-8000-000000050d04","qty":3}]', pg_temp.k(16)) $$, 'a delivery of 3 gloves');
select lives_ok($$ select public.undo_action(pg_temp.action(16), pg_temp.k(17)) $$, 'nothing of which was used is undone as before');
reset role;

-- Stock already below 0 is repaired once ---------------------------------------------------------------------------------
-- Before the fix: Cotton rolls at -3 undated with a delivery of 5 since; Prophy paste at -2 from a Cleaning; Matrix bands
-- at -1 with no procedure behind it (an Undo); Bite blocks at -4 from a Crown that took 2 of 1 and a Root canal that took
-- 3 more.
alter table public.batches drop constraint batches_qty_not_negative;
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target) values
  ('00000000-0000-4000-8000-000000050e01', '00000000-0000-4000-8000-000000050c01', 'Cotton rolls', 'packs', 'countable', 2, 10),
  ('00000000-0000-4000-8000-000000050e02', '00000000-0000-4000-8000-000000050c01', 'Prophy paste', 'cups', 'countable', 2, 10),
  ('00000000-0000-4000-8000-000000050e03', '00000000-0000-4000-8000-000000050c01', 'Matrix bands', 'packs', 'countable', 1, 5),
  ('00000000-0000-4000-8000-000000050e04', '00000000-0000-4000-8000-000000050c01', 'Bite blocks', 'pieces', 'countable', 1, 5);
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000050f11', '00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050e01',
   date_trunc('month', current_date + interval '8 months')::date, 'C1', 5),
  ('00000000-0000-4000-8000-000000050f12', '00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050e01', null, null, -3),
  ('00000000-0000-4000-8000-000000050f22', '00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050e02', null, null, -2),
  ('00000000-0000-4000-8000-000000050f32', '00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050e03', null, null, -1),
  ('00000000-0000-4000-8000-000000050f42', '00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050e04', null, null, -4);
insert into public.procedure_events (id, clinic_id, name, started_by, started_at) values
  ('00000000-0000-4000-8000-000000050e21', '00000000-0000-4000-8000-000000050c01', 'Cleaning', '00000000-0000-4000-8000-000000050a02', now() - interval '3 days'),
  ('00000000-0000-4000-8000-000000050e41', '00000000-0000-4000-8000-000000050c01', 'Crown', '00000000-0000-4000-8000-000000050a01', now() - interval '2 days'),
  ('00000000-0000-4000-8000-000000050e42', '00000000-0000-4000-8000-000000050c01', 'Root canal', '00000000-0000-4000-8000-000000050a02', now() - interval '1 day');
insert into public.procedure_event_items (clinic_id, event_id, product_id, qty) values
  ('00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050e21', '00000000-0000-4000-8000-000000050e02', 2),
  ('00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050e41', '00000000-0000-4000-8000-000000050e04', 2),
  ('00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050e42', '00000000-0000-4000-8000-000000050e04', 3);
insert into public.transactions (clinic_id, product_id, batch_id, type, delta, qty_before, qty_after, by_user, at, ref_type, ref_id, ref_label, action_id) values
  ('00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050e02', '00000000-0000-4000-8000-000000050f22', 'procedure', -2, 0, -2,
   '00000000-0000-4000-8000-000000050a02', now() - interval '3 days', 'procedure_event', '00000000-0000-4000-8000-000000050e21', 'Cleaning', '00000000-0000-4000-8000-000000050e21'),
  ('00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050e04', '00000000-0000-4000-8000-000000050f42', 'procedure', -2, 1, -1,
   '00000000-0000-4000-8000-000000050a01', now() - interval '2 days', 'procedure_event', '00000000-0000-4000-8000-000000050e41', 'Crown', '00000000-0000-4000-8000-000000050e41'),
  ('00000000-0000-4000-8000-000000050c01', '00000000-0000-4000-8000-000000050e04', '00000000-0000-4000-8000-000000050f42', 'procedure', -3, -1, -4,
   '00000000-0000-4000-8000-000000050a02', now() - interval '1 day', 'procedure_event', '00000000-0000-4000-8000-000000050e42', 'Root canal', '00000000-0000-4000-8000-000000050e42');

select is(engine.repair_negative_stock(), 4, 'the four batches below 0 are repaired');
select lives_ok($$ alter table public.batches add constraint batches_qty_not_negative check (qty >= 0) $$,
  'after which every batch holds 0 or more, so the check goes back on');
select results_eq(
  $$ select pg_temp.batch_qty('00000000-0000-4000-8000-000000050f11'), pg_temp.batch_qty('00000000-0000-4000-8000-000000050f12'),
            pg_temp.qty('00000000-0000-4000-8000-000000050e01'),
            (select count(*) from public.transactions where product_id = '00000000-0000-4000-8000-000000050e01') $$,
  $$ values (2::numeric, 0::numeric, 2::numeric, 0::bigint) $$,
  'Cotton rolls: the delivery covers the shortfall, the product still holds 2, and nothing is written');
select results_eq(
  $$ select t.type::text, t.delta, t.qty_before, t.qty_after, t.ref_type::text, t.ref_id, t.by_user, t.ref_label, t.reason
     from public.transactions t
     where t.product_id = '00000000-0000-4000-8000-000000050e02' and t.reason = 'Data correction' $$,
  $$ values ('adjustment', 2::numeric, -2::numeric, 0::numeric, 'procedure_event', '00000000-0000-4000-8000-000000050e21'::uuid,
             '00000000-0000-4000-8000-000000050a02'::uuid, 'Stock below 0 set to 0', 'Data correction') $$,
  'Prophy paste: set to 0 by a correction charged to the Cleaning, in Michael''s name');
select results_eq(
  $$ select t.delta, t.ref_type::text, t.ref_id, t.by_user, pg_temp.qty('00000000-0000-4000-8000-000000050e03')
     from public.transactions t where t.product_id = '00000000-0000-4000-8000-000000050e03' $$,
  $$ values (1::numeric, 'manual', null::uuid, '00000000-0000-4000-8000-000000050a01'::uuid, 0::numeric) $$,
  'Matrix bands: a plain correction to 0, in the name of the clinic''s first admin');
select results_eq(
  $$ select engine.procedure_taken('00000000-0000-4000-8000-000000050e42', '00000000-0000-4000-8000-000000050e04'),
            engine.procedure_taken('00000000-0000-4000-8000-000000050e41', '00000000-0000-4000-8000-000000050e04'),
            pg_temp.qty('00000000-0000-4000-8000-000000050e04') $$,
  $$ values (0::numeric, 1::numeric, 0::numeric) $$,
  'Bite blocks: the latest procedure is charged first, so the Root canal took none from stock and the Crown 1');
select is((select qty from public.to_buy_items where product_id = '00000000-0000-4000-8000-000000050e02' and status = 'to_buy'),
  10::numeric, 'a repaired product follows its status: Prophy paste goes on To buy');
select pg_temp.act_as('00000000-0000-4000-8000-000000050a02');
select throws_ok($$ select public.undo_action(
    (select action_id from public.transactions where product_id = '00000000-0000-4000-8000-000000050e02' and reason = 'Data correction'),
    pg_temp.k(18)) $$,
  '22023', 'this action cannot be undone', 'a correction cannot be undone');
select lives_ok($$ select public.stock_procedure_cancel('00000000-0000-4000-8000-000000050e21', 'Logged twice', pg_temp.k(19)) $$,
  'the Cleaning is cancelled later');
select is(pg_temp.qty('00000000-0000-4000-8000-000000050e02'), 0::numeric, 'and gives back nothing, since its 2 never came from stock');
reset role;

select * from finish();
rollback;
