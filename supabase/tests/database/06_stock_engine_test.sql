-- The stock engine: every function writes the ledger and keeps batches and open items right, soonest
-- expiry goes first and shortfalls land on the undated batch, retries change nothing, cancelling gives
-- back to the original batches, Undo has its window and owner, and permissions hold.
begin;
select plan(95);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin1@medisave.test'),
  ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'staff1@medisave.test'),
  ('00000000-0000-4000-8000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin2@medisave.test');
insert into public.clinics (id, name, country, currency) values
  ('00000000-0000-4000-8000-0000000000c1', 'Smile Dental', 'US', 'USD'),
  ('00000000-0000-4000-8000-0000000000c2', 'Other Dental', 'CA', 'CAD');
insert into public.memberships (clinic_id, user_id, email, role, status) values
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', 'admin1@medisave.test', 'admin', 'active'),
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000b1', 'staff1@medisave.test', 'staff', 'active'),
  ('00000000-0000-4000-8000-0000000000c2', '00000000-0000-4000-8000-0000000000a2', 'admin2@medisave.test', 'admin', 'active');
-- Clinic 1: Septocaine (countable, 20 expiring Dec 2026 + 34 Mar 2027 + 3 undated), Bonding agent
-- (multi-use, 2 unopened), Gloves (countable, empty, minimum 3, target 10).
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target) values
  ('00000000-0000-4000-8000-0000000000d1', '00000000-0000-4000-8000-0000000000c1', 'Septocaine 4% 1:100,000', 'cartridges', 'countable', 20, 60),
  ('00000000-0000-4000-8000-0000000000d2', '00000000-0000-4000-8000-0000000000c1', 'Bonding agent', 'bottles', 'multi_use', 1, 3),
  ('00000000-0000-4000-8000-0000000000d3', '00000000-0000-4000-8000-0000000000c1', 'Nitrile gloves M', 'boxes', 'countable', 3, 10),
  ('00000000-0000-4000-8000-0000000000d9', '00000000-0000-4000-8000-0000000000c2', 'Composite A2', 'syringes', 'countable', 1, 5);
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d1', '2026-12-01', 'A112', 20),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d1', '2027-03-01', 'B441', 34),
  ('00000000-0000-4000-8000-0000000000e3', '00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d1', null, null, 3),
  ('00000000-0000-4000-8000-0000000000e4', '00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d2', null, null, 2);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.qty(p uuid) returns numeric language sql as $$ select quantity from public.product_stock where product_id = p $$;
create function pg_temp.batch_qty(b uuid) returns numeric language sql as $$ select qty from public.batches where id = b $$;
create function pg_temp.ledger_count(p uuid) returns bigint language sql as $$ select count(*) from public.transactions where product_id = p $$;
create function pg_temp.k(n int) returns uuid language sql as $$ select ('00000000-0000-4000-8000-00000000f' || lpad(n::text, 3, '0'))::uuid $$;

-- Receive (admin only) -----------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-0000000000b1');
select throws_ok($$ select public.stock_receive('00000000-0000-4000-8000-0000000000c1', '[{"product_id":"00000000-0000-4000-8000-0000000000d1","qty":5}]', pg_temp.k(1)) $$,
  '42501', null, 'staff cannot receive');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000000000a1');
select lives_ok($$ select public.stock_receive('00000000-0000-4000-8000-0000000000c1',
  '[{"product_id":"00000000-0000-4000-8000-0000000000d1","qty":50,"unit_cost":0.99,"lot":"A112","expiry_month":"2026-12-01"},
    {"product_id":"00000000-0000-4000-8000-0000000000d3","qty":10,"unit_cost":8.5}]',
  pg_temp.k(2), 'invoice', '00000000-0000-4000-8000-000000000f01', 'Invoice INV-10092') $$, 'admin receives two lines');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e1'), 70::numeric, 'the same lot and expiry adds to the existing batch');
select is(pg_temp.qty('00000000-0000-4000-8000-0000000000d3'), 10::numeric, 'a new product gets a new batch');
select is((select last_unit_cost from public.products where id = '00000000-0000-4000-8000-0000000000d1'), 0.99::numeric, 'last unit cost is updated');
select is((select count(*) from public.transactions where type = 'receiving' and ref_label = 'Invoice INV-10092'), 2::bigint, 'one receiving row per line');
select is((select qty_before || '→' || qty_after from public.transactions where product_id = '00000000-0000-4000-8000-0000000000d1' and type = 'receiving'), '57.00→107.00', 'totals are recorded around the row');
select is((select count(*) from public.alerts where product_id = '00000000-0000-4000-8000-0000000000d1' and kind = 'expiring' and resolved_at is null),
  (select count(*) from unnest(array[30, 60, 90]) t where public.days_to_expiry('2026-12-01', 'UTC') <= t), 'the December batch opens one expiring alert per threshold it has crossed');

-- Idempotency ----------------------------------------------------------------------------------------
select is(
  public.stock_receive('00000000-0000-4000-8000-0000000000c1', '[{"product_id":"00000000-0000-4000-8000-0000000000d3","qty":10}]', pg_temp.k(2)),
  (select id from public.stock_actions where idempotency_key = pg_temp.k(2)), 'a retry returns the first action');
select is(pg_temp.qty('00000000-0000-4000-8000-0000000000d3'), 10::numeric, 'and changes nothing');

-- Procedure start: FEFO, take-new, negative stock ------------------------------------------------------
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000000000b1');
select lives_ok($$ select public.stock_procedure_start('00000000-0000-4000-8000-0000000000c1', null, 'Root canal',
  '[{"product_id":"00000000-0000-4000-8000-0000000000d1","qty":75},{"product_id":"00000000-0000-4000-8000-0000000000d3","qty":12}]',
  array['00000000-0000-4000-8000-0000000000d2']::uuid[], pg_temp.k(3)) $$, 'staff starts a procedure');
select is((select id from public.procedure_events where name = 'Root canal'), (select id from public.stock_actions where idempotency_key = pg_temp.k(3)), 'the event id is the action id');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e1'), 0::numeric, 'the soonest batch is emptied first');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e2'), 29::numeric, 'then the next one');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e3'), 3::numeric, 'undated stock is taken last');
select is(pg_temp.qty('00000000-0000-4000-8000-0000000000d3'), -2::numeric, 'stock may go negative');
select is((select qty from public.batches where product_id = '00000000-0000-4000-8000-0000000000d3' and expiry_month is null and lot is null), -2::numeric, 'and the shortfall sits on the undated batch');
select is((select count(*) from public.open_items where product_id = '00000000-0000-4000-8000-0000000000d2' and finished_at is null), 1::bigint, 'take-new opened a bottle');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e4'), 1::numeric, 'from the unopened stock');
select is(pg_temp.qty('00000000-0000-4000-8000-0000000000d2'), 2::numeric, 'opening does not change the multi-use total');
select is((select count(*) from public.transactions where ref_type = 'procedure_event' and ref_label = 'Root canal' and batch_id is not null), 5::bigint, 'one ledger row per batch touched');
select is((select status from public.to_buy_items where product_id = '00000000-0000-4000-8000-0000000000d3' and status = 'to_buy'), 'to_buy', 'an out-of-stock product is added to To buy');
select is((select qty from public.to_buy_items where product_id = '00000000-0000-4000-8000-0000000000d3' and status = 'to_buy'), 12::numeric, 'with target minus current');
select is((select count(*) from public.alerts where product_id = '00000000-0000-4000-8000-0000000000d3' and kind = 'out_of_stock' and resolved_at is null), 1::bigint, 'and an out-of-stock alert');
select is(public.product_status_of('00000000-0000-4000-8000-0000000000d1'), 'missing_expiry', 'Septocaine still has undated stock');

-- Procedure edit: only the differences ---------------------------------------------------------------
select lives_ok($$ select public.stock_procedure_edit((select id from public.stock_actions where idempotency_key = pg_temp.k(3)),
  '[{"product_id":"00000000-0000-4000-8000-0000000000d1","qty":70},{"product_id":"00000000-0000-4000-8000-0000000000d3","qty":12}]',
  array[]::uuid[], pg_temp.k(4)) $$, 'usage is edited');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e2'), 34::numeric, 'the 5 returned go to the batch they came from');
select is((select qty from public.procedure_event_items where product_id = '00000000-0000-4000-8000-0000000000d1'), 70::numeric, 'the event records the new quantity');
select is((select count(*) from public.open_items where product_id = '00000000-0000-4000-8000-0000000000d2' and finished_at is null), 0::bigint, 'removing take-new puts the bottle back');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e4'), 2::numeric, 'into its batch');
select is((select count(*) from public.transactions where ref_label = 'Edited usage · Root canal'), 2::bigint, 'edits are their own ledger rows');

-- Procedure cancel ---------------------------------------------------------------------------------
select lives_ok($$ select public.stock_procedure_start('00000000-0000-4000-8000-0000000000c1', null, 'Filling',
  '[{"product_id":"00000000-0000-4000-8000-0000000000d1","qty":4}]', array['00000000-0000-4000-8000-0000000000d2']::uuid[], pg_temp.k(5)) $$, 'another procedure starts');
select lives_ok($$ select public.bottle_finish((select id from public.open_items where product_id = '00000000-0000-4000-8000-0000000000d2' and finished_at is null), pg_temp.k(6)) $$, 'its bottle is finished');
select throws_ok($$ select public.stock_procedure_cancel((select id from public.stock_actions where idempotency_key = pg_temp.k(5)), '  ', pg_temp.k(7)) $$,
  '22023', null, 'cancelling needs a note');
select lives_ok($$ select public.stock_procedure_cancel((select id from public.stock_actions where idempotency_key = pg_temp.k(5)), 'Logged by mistake', pg_temp.k(7)) $$, 'cancelled with a note');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e2'), 34::numeric, 'the 4 cartridges are back in their batch');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e4'), 1::numeric, 'a finished bottle stays finished');
select is((select cancel_note from public.procedure_events where id = (select id from public.stock_actions where idempotency_key = pg_temp.k(5))), 'Logged by mistake', 'the note is recorded');
select is((select count(*) from public.transactions where type = 'cancellation'), 1::bigint, 'the return is a cancellation row');
select throws_ok($$ select public.stock_procedure_edit((select id from public.stock_actions where idempotency_key = pg_temp.k(5)), '[]', array[]::uuid[], pg_temp.k(8)) $$,
  '22023', null, 'a cancelled procedure cannot be edited');

-- Count -----------------------------------------------------------------------------------------------
select lives_ok($$ select public.stock_count_apply('00000000-0000-4000-8000-0000000000c1',
  '[{"product_id":"00000000-0000-4000-8000-0000000000d1","counted":30},{"product_id":"00000000-0000-4000-8000-0000000000d2","counted":3}]', pg_temp.k(9)) $$, 'a count is applied');
select is(pg_temp.qty('00000000-0000-4000-8000-0000000000d1'), 30::numeric, 'the countable now holds the counted quantity');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e2'), 27::numeric, 'a decrease takes from the soonest batch');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e4'), 3::numeric, 'an increase goes to the undated batch');
select is((select count(*) from public.transactions where type = 'count' and reason = 'Physical count'), 2::bigint, 'one count row per changed product');
select is(public.product_status_of('00000000-0000-4000-8000-0000000000d1'), 'missing_expiry', 'with the December batch empty, Septocaine is only missing expiry');
select is((select count(*) from public.alerts where product_id = '00000000-0000-4000-8000-0000000000d1' and kind = 'expiring' and resolved_at is null), 0::bigint, 'its expiring alerts closed when the batch emptied');
select is((select count(*) from public.alerts where product_id = '00000000-0000-4000-8000-0000000000d1' and kind = 'missing_expiry' and resolved_at is null), 1::bigint, 'and a missing-expiry alert is open');

-- Adjust ----------------------------------------------------------------------------------------------
select throws_ok($$ select public.stock_adjust('00000000-0000-4000-8000-0000000000d1', 28, 'Because', null, pg_temp.k(10)) $$,
  '22023', null, 'an adjustment needs a known reason');
select lives_ok($$ select public.stock_adjust('00000000-0000-4000-8000-0000000000d1', 28, 'Damaged', 'Dropped a box', pg_temp.k(10)) $$, 'an adjustment is written');
select is(pg_temp.qty('00000000-0000-4000-8000-0000000000d1'), 28::numeric, 'with the actual quantity');
select is((select note from public.transactions where type = 'adjustment' and reason = 'Damaged'), 'Dropped a box', 'and its note');

-- Undo (MS-100 D10) -------------------------------------------------------------------------------------
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000000000a1');
select throws_ok($$ select public.undo_action((select id from public.stock_actions where idempotency_key = pg_temp.k(10)), pg_temp.k(11)) $$,
  '42501', null, 'someone else cannot undo it');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000000000b1');
select lives_ok($$ select public.undo_action((select id from public.stock_actions where idempotency_key = pg_temp.k(10)), pg_temp.k(11)) $$, 'the same user undoes within 10 seconds');
select is(pg_temp.qty('00000000-0000-4000-8000-0000000000d1'), 30::numeric, 'the adjustment is reversed');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e3'), 5::numeric, 'the two units come back as undated stock (MS-100 D9)');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e2'), 25::numeric, 'the dated batch keeps what the adjustment took');
select is((select count(*) from public.transactions where ref_type = 'undo' and reverses_id is not null), 1::bigint, 'as a reversal row');
select throws_ok($$ select public.undo_action((select id from public.stock_actions where idempotency_key = pg_temp.k(10)), pg_temp.k(12)) $$,
  '22023', null, 'it cannot be undone twice');
select throws_ok($$ select public.undo_action((select id from public.stock_actions where idempotency_key = pg_temp.k(9)), pg_temp.k(13)) $$,
  '22023', null, 'a count cannot be undone');
reset role;
update public.stock_actions set created_at = now() - interval '11 seconds' where idempotency_key = pg_temp.k(2);
select pg_temp.act_as('00000000-0000-4000-8000-0000000000a1');
select throws_ok($$ select public.undo_action((select id from public.stock_actions where idempotency_key = pg_temp.k(2)), pg_temp.k(14)) $$,
  '22023', null, 'the window closes after 10 seconds');

-- Undo of an upward adjustment, a receiving and a disposal --------------------------------------------
select lives_ok($$ select public.stock_adjust('00000000-0000-4000-8000-0000000000d1', 33, 'Returned', null, pg_temp.k(40)) $$, 'adjust upwards');
select lives_ok($$ select public.undo_action((select id from public.stock_actions where idempotency_key = pg_temp.k(40)), pg_temp.k(41)) $$, 'and undo it');
select is(pg_temp.qty('00000000-0000-4000-8000-0000000000d1'), 30::numeric, 'the upward adjustment is reversed');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e3'), 5::numeric, 'through the undated batch it was added to');
select is((select count(*) from public.transactions where reverses_id = (select id from public.transactions where action_id = (select id from public.stock_actions where idempotency_key = pg_temp.k(40)))), 1::bigint, 'with a reversal row pointing at it');
select lives_ok($$ select public.stock_receive('00000000-0000-4000-8000-0000000000c1', '[{"product_id":"00000000-0000-4000-8000-0000000000d3","qty":4}]', pg_temp.k(42)) $$, 'receive gloves while their To buy line was never ordered');
select is((select status from public.to_buy_items where product_id = '00000000-0000-4000-8000-0000000000d3' order by created_at limit 1), 'received', 'the To buy line is received');
select is(pg_temp.qty('00000000-0000-4000-8000-0000000000d3'), 2::numeric, 'the shortfall is covered');
select lives_ok($$ select public.undo_action((select id from public.stock_actions where idempotency_key = pg_temp.k(42)), pg_temp.k(43)) $$, 'a receiving can be undone');
select is(pg_temp.qty('00000000-0000-4000-8000-0000000000d3'), -2::numeric, 'and the stock goes back');
select lives_ok($$ select public.stock_procedure_edit((select id from public.stock_actions where idempotency_key = pg_temp.k(3)), '[{"product_id":"00000000-0000-4000-8000-0000000000d1","qty":69},{"product_id":"00000000-0000-4000-8000-0000000000d3","qty":12}]', array[]::uuid[], pg_temp.k(44)) $$, 'a procedure can be edited a second time');
select lives_ok($$ select public.stock_procedure_edit((select id from public.stock_actions where idempotency_key = pg_temp.k(3)), '[{"product_id":"00000000-0000-4000-8000-0000000000d1","qty":70},{"product_id":"00000000-0000-4000-8000-0000000000d3","qty":12}]', array[]::uuid[], pg_temp.k(47)) $$, 'and a third time in the same transaction');
select is(pg_temp.qty('00000000-0000-4000-8000-0000000000d1'), 30::numeric, 'two opposite edits leave the total as it was');

-- Dispose (admin only) ---------------------------------------------------------------------------------
select throws_ok($$ select public.stock_dispose('00000000-0000-4000-8000-0000000000e2', 99, pg_temp.k(15)) $$,
  '22023', null, 'cannot dispose more than the batch holds');
create temp table snap as select pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e2') as e2, pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e3') as e3, pg_temp.qty('00000000-0000-4000-8000-0000000000d1') as d1;
select lives_ok($$ select public.stock_dispose('00000000-0000-4000-8000-0000000000e2', 7, pg_temp.k(15)) $$, 'admin disposes 7');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e2'), (select e2 - 7 from snap), 'from that batch');
select is((select reason from public.transactions where type = 'disposal'), 'Expired', 'with the reason Expired');
select lives_ok($$ select public.undo_action((select id from public.stock_actions where idempotency_key = pg_temp.k(15)), pg_temp.k(45)) $$, 'a disposal can be undone');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e2'), (select e2 from snap), 'and the batch is whole again');
select lives_ok($$ select public.stock_dispose('00000000-0000-4000-8000-0000000000e2', 7, pg_temp.k(46)) $$, 'then disposed again for the rest of the test');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000000000b1');
select throws_ok($$ select public.stock_dispose('00000000-0000-4000-8000-0000000000e2', 1, pg_temp.k(16)) $$, '42501', null, 'staff cannot dispose');

-- Add expiry and edit batch ------------------------------------------------------------------------------
select lives_ok($$ select public.batch_upsert('00000000-0000-4000-8000-0000000000d1', null, '2027-06-01', 2, 'C7', pg_temp.k(17)) $$, 'add expiry to undated stock');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e3'), (select e3 - 2 from snap), 'moves it out of the undated batch');
select is(pg_temp.qty('00000000-0000-4000-8000-0000000000d1'), (select d1 - 7 from snap), 'with no net change');
select lives_ok($$ select public.batch_upsert('00000000-0000-4000-8000-0000000000d1', '00000000-0000-4000-8000-0000000000e2', '2027-03-01', (select e2 - 2 from snap), 'B441', pg_temp.k(18)) $$, 'edit a batch quantity');
select is((select reason from public.transactions where ref_label = 'Edit batch'), 'Data correction', 'an edited quantity is a data correction');
select is(pg_temp.qty('00000000-0000-4000-8000-0000000000d1'), (select d1 - 2 from snap), 'the total follows');

-- Bottles -------------------------------------------------------------------------------------------------
select lives_ok($$ select public.bottle_open('00000000-0000-4000-8000-0000000000d2', pg_temp.k(19)) $$, 'open a bottle');
select lives_ok($$ select public.bottle_open('00000000-0000-4000-8000-0000000000d2', pg_temp.k(20)) $$, 'and another');
select is((select count(*) from public.open_items where product_id = '00000000-0000-4000-8000-0000000000d2' and finished_at is null), 2::bigint, 'two bottles are open');
select is(pg_temp.batch_qty('00000000-0000-4000-8000-0000000000e4'), 1::numeric, 'one unopened is left');
select throws_ok($$ select public.bottle_open('00000000-0000-4000-8000-0000000000d1', pg_temp.k(21)) $$, '22023', null, 'a countable cannot be opened');

-- Other clinic and read-only -------------------------------------------------------------------------------
select throws_ok($$ select public.stock_adjust('00000000-0000-4000-8000-0000000000d9', 1, 'Other', null, pg_temp.k(22)) $$, '42501', null, 'another clinic''s product is refused');
reset role;
update public.clinics set subscription_status = 'read_only' where id = '00000000-0000-4000-8000-0000000000c1';
select pg_temp.act_as('00000000-0000-4000-8000-0000000000a1');
select throws_ok($$ select public.stock_adjust('00000000-0000-4000-8000-0000000000d1', 1, 'Other', null, pg_temp.k(23)) $$, '42501', null, 'a read-only clinic takes no stock changes');
reset role;

select * from finish();
rollback;
