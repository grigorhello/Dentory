-- MS-124 fix (#95) · A retry with the same idempotency key returns the first result and changes nothing, also once the
-- state the function checks has changed: a cancel retried after it cancelled the procedure, an edit retried after a
-- colleague cancelled it, an undo retried after it undid the action and after the 10-second window, and Adjust, Add
-- expiry, Mark disposed, Open a new bottle and Finished retried after an admin deleted the product (Open a new bottle
-- also after the product was made countable). A first call is still refused with the same sentence and leaves no action
-- behind, and the permission checks still come before the lookup: another clinic's member, someone else's undo and a
-- read-only clinic are refused on a retry too. Also: undoing a decrease gives the units back as undated stock when the
-- product had none.
begin;
select plan(54);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000038101', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000038102', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000038103', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone) values
  ('00000000-0000-4000-8000-000000038111', 'Smile Dental', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-000000038112', 'Other Dental', 'CA', 'CAD', 'America/Toronto');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000038111', '00000000-0000-4000-8000-000000038101', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000038111', '00000000-0000-4000-8000-000000038102', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000038112', '00000000-0000-4000-8000-000000038103', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
-- Septocaine for the procedures and the undo; Bonding agent for the product functions, deleted halfway; Etchant has one
-- kit, opened, finished and then made countable.
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target) values
  ('00000000-0000-4000-8000-000000038121', '00000000-0000-4000-8000-000000038111', 'Septocaine', 'cartridges', 'countable', 10, 60),
  ('00000000-0000-4000-8000-000000038122', '00000000-0000-4000-8000-000000038111', 'Bonding agent', 'bottles', 'multi_use', 0, 4),
  ('00000000-0000-4000-8000-000000038123', '00000000-0000-4000-8000-000000038111', 'Etchant', 'kits', 'multi_use', 0, 2);
insert into public.batches (id, clinic_id, product_id, expiry_month, qty) values
  ('00000000-0000-4000-8000-000000038131', '00000000-0000-4000-8000-000000038111', '00000000-0000-4000-8000-000000038121',
   date_trunc('month', current_date + interval '10 months')::date, 50),
  ('00000000-0000-4000-8000-000000038132', '00000000-0000-4000-8000-000000038111', '00000000-0000-4000-8000-000000038122',
   date_trunc('month', current_date + interval '6 months')::date, 5),
  ('00000000-0000-4000-8000-000000038133', '00000000-0000-4000-8000-000000038111', '00000000-0000-4000-8000-000000038123',
   date_trunc('month', current_date + interval '10 months')::date, 1);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.k(p_n text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000000383' || p_n)::uuid
$$;
-- The action a key registered (a started procedure's id is its action's id), read past row-level security so that
-- another clinic's member can be handed it.
create function pg_temp.action(p_key text) returns uuid language sql security definer as $$
  select id from public.stock_actions
  where clinic_id = '00000000-0000-4000-8000-000000038111' and idempotency_key = pg_temp.k(p_key)
$$;
create function pg_temp.actions(p_keys text[]) returns bigint language sql security definer as $$
  select count(*) from public.stock_actions
  where idempotency_key in (select pg_temp.k(n) from unnest(p_keys) n)
$$;
create function pg_temp.septocaine() returns numeric language sql as $$
  select quantity from public.product_stock where product_id = '00000000-0000-4000-8000-000000038121'
$$;
create function pg_temp.bottle(p_product uuid) returns uuid language sql as $$
  select id from public.open_items where product_id = p_product
$$;
-- The calls Edit usage, Cancel procedure and the product sheets send, as the write queue sends them again.
create function pg_temp.cancel(p_event text, p_note text, p_key text) returns uuid language sql as $$
  select public.stock_procedure_cancel(pg_temp.action(p_event), p_note, pg_temp.k(p_key))
$$;
create function pg_temp.edit_crown(p_qty int, p_key text) returns uuid language sql as $$
  select public.stock_procedure_edit(pg_temp.action('a3'),
    jsonb_build_array(jsonb_build_object('product_id', '00000000-0000-4000-8000-000000038121', 'qty', p_qty)),
    '{}'::uuid[], pg_temp.k(p_key))
$$;
create function pg_temp.undo(p_action text, p_key text) returns uuid language sql as $$
  select public.undo_action(pg_temp.action(p_action), pg_temp.k(p_key))
$$;
create function pg_temp.add_expiry(p_lot text, p_key text) returns uuid language sql as $$
  select public.batch_upsert('00000000-0000-4000-8000-000000038122', null,
    date_trunc('month', current_date + interval '8 months')::date, 1, p_lot, pg_temp.k(p_key))
$$;

-- Michael performs three procedures with Septocaine: 2, 1 and 1 of its 50.
select pg_temp.act_as('00000000-0000-4000-8000-000000038102');
select lives_ok($$
  select public.stock_procedure_start('00000000-0000-4000-8000-000000038111', null, name,
    jsonb_build_array(jsonb_build_object('product_id', '00000000-0000-4000-8000-000000038121', 'qty', qty)),
    '{}'::uuid[], pg_temp.k(key))
  from (values ('Root canal', 2, 'a1'), ('Filling', 1, 'a2'), ('Crown', 1, 'a3')) v (name, qty, key)
$$, 'Michael performs a Root canal, a Filling and a Crown');

-- Cancel procedure, then the same cancel again, as the write queue replays one whose answer was lost.
select lives_ok($$ select pg_temp.cancel('a1', 'Logged by mistake', 'c1') $$, 'Michael cancels the Root canal');
select is(pg_temp.septocaine(), 48::numeric, 'its 2 Septocaine are back');
select is(pg_temp.cancel('a1', 'Logged by mistake', 'c1'), pg_temp.action('c1'), 'the same cancel again returns the first result');
select is(pg_temp.septocaine(), 48::numeric, 'and gives nothing back twice');
reset role;
select is((select count(*) from public.transactions where type = 'cancellation' and ref_id = pg_temp.action('a1')), 1::bigint,
  'the ledger keeps its one return');
select results_eq($$
  select count(*), min(cancel_note) from public.procedure_events
  where id = pg_temp.action('a1') and cancelled_by = '00000000-0000-4000-8000-000000038102'
$$, $$ values (1::bigint, 'Logged by mistake') $$, 'and the procedure its one cancellation');
select is(pg_temp.actions(array['c1']), 1::bigint, 'with one action');
select pg_temp.act_as('00000000-0000-4000-8000-000000038102');
select throws_ok($$ select pg_temp.cancel('a1', 'Logged twice', 'c2') $$,
  '22023', 'the procedure was already cancelled', 'a new cancel of the cancelled Root canal is still refused');
reset role;
select is(pg_temp.actions(array['c2']), 0::bigint, 'and leaves no action behind');

-- Another clinic's member is refused before the lookup.
select pg_temp.act_as('00000000-0000-4000-8000-000000038103');
select throws_ok($$ select pg_temp.cancel('a2', 'Logged by mistake', 'c3') $$,
  '42501', 'not a member of this clinic', 'a member of another clinic cannot cancel the Filling');
select throws_ok($$ select pg_temp.cancel('a1', 'Logged by mistake', 'c1') $$,
  '42501', 'not a member of this clinic', 'nor get the Root canal''s cancel by sending its key again');
reset role;

-- Edit usage, then a colleague cancels, then the same edit again.
select pg_temp.act_as('00000000-0000-4000-8000-000000038102');
select lives_ok($$ select pg_temp.edit_crown(3, 'b1') $$, 'Michael raises the Crown''s Septocaine from 1 to 3');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000038101');
select lives_ok($$ select pg_temp.cancel('a3', 'Patient cancelled', 'c5') $$, 'Sarah cancels the Crown');
reset role;
select is(pg_temp.septocaine(), 49::numeric, 'its 3 Septocaine are back');
select pg_temp.act_as('00000000-0000-4000-8000-000000038102');
select is(pg_temp.edit_crown(3, 'b1'), pg_temp.action('b1'), 'Michael''s edit sent again returns its first result');
select is(pg_temp.septocaine(), 49::numeric, 'and takes nothing again');
select throws_ok($$ select pg_temp.edit_crown(2, 'b2') $$,
  '22023', 'the procedure was cancelled', 'a new edit of the cancelled Crown is still refused');
reset role;
select is(pg_temp.actions(array['b2']), 0::bigint, 'and leaves no action behind');

-- Undo, then the same undo again once the 10 seconds are over.
select pg_temp.act_as('00000000-0000-4000-8000-000000038102');
select lives_ok($$ select public.stock_adjust('00000000-0000-4000-8000-000000038121', 45, 'Damaged', null, pg_temp.k('d1')) $$,
  'Michael sets Septocaine to 45, Damaged');
select lives_ok($$ select pg_temp.undo('d1', 'd2') $$, 'and undoes it');
select is(pg_temp.septocaine(), 49::numeric, 'Septocaine is back at 49');
reset role;
select is((select qty from public.batches where product_id = '00000000-0000-4000-8000-000000038121' and expiry_month is null),
  4::numeric, 'the 4 come back as undated stock (MS-100 D9), in the undated batch the undo had to create');
update public.stock_actions set created_at = now() - interval '11 seconds' where id = pg_temp.action('d1');
select pg_temp.act_as('00000000-0000-4000-8000-000000038102');
select is(pg_temp.undo('d1', 'd2'), pg_temp.action('d2'), 'the same undo after the 10 seconds returns its first result');
select is(pg_temp.septocaine(), 49::numeric, 'and reverses nothing twice');
reset role;
select is((select count(*) from public.transactions where ref_type = 'undo' and ref_id = pg_temp.action('d1')), 1::bigint,
  'the ledger keeps its one reversal');
select pg_temp.act_as('00000000-0000-4000-8000-000000038102');
select throws_ok($$ select pg_temp.undo('d1', 'd3') $$, '22023', 'already undone', 'a new undo of it is still refused');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000038101');
select throws_ok($$ select pg_temp.undo('d1', 'd2') $$,
  '42501', 'only the person who did it can undo it', 'Sarah sending Michael''s undo again is refused before the lookup');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000038102');
select lives_ok($$ select public.stock_adjust('00000000-0000-4000-8000-000000038121', 40, 'Damaged', null, pg_temp.k('d4')) $$,
  'Michael sets Septocaine to 40');
reset role;
update public.stock_actions set created_at = now() - interval '11 seconds' where id = pg_temp.action('d4');
select pg_temp.act_as('00000000-0000-4000-8000-000000038102');
select throws_ok($$ select pg_temp.undo('d4', 'd5') $$, '22023', 'the undo window has passed',
  'an undo first sent after the 10 seconds is still refused');
reset role;
select is(pg_temp.actions(array['d3', 'd5']), 0::bigint, 'the refused undos leave no action behind');

-- Adjust, Add expiry, Mark disposed, Open a new bottle and Finished on Bonding agent, which Sarah then deletes.
select pg_temp.act_as('00000000-0000-4000-8000-000000038101');
select lives_ok($$ select public.stock_adjust('00000000-0000-4000-8000-000000038122', 6, 'Returned', null, pg_temp.k('e1')) $$,
  'Sarah sets Bonding agent to 6, the new one undated');
select lives_ok($$ select pg_temp.add_expiry('L7', 'e2') $$, 'gives it an expiry');
select lives_ok($$ select public.stock_dispose('00000000-0000-4000-8000-000000038132', 1, pg_temp.k('e3')) $$,
  'disposes of 1 from the batch expiring first');
select lives_ok($$ select public.bottle_open('00000000-0000-4000-8000-000000038122', pg_temp.k('e4')) $$, 'opens a bottle');
select lives_ok($$ select public.bottle_finish(pg_temp.bottle('00000000-0000-4000-8000-000000038122'), pg_temp.k('e5')) $$,
  'and finishes it');
select lives_ok($$ select public.product_archive('00000000-0000-4000-8000-000000038122') $$, 'then deletes Bonding agent');
select results_eq($$
  select public.stock_adjust('00000000-0000-4000-8000-000000038122', 6, 'Returned', null, pg_temp.k('e1'))
  union all select pg_temp.add_expiry('L7', 'e2')
  union all select public.stock_dispose('00000000-0000-4000-8000-000000038132', 1, pg_temp.k('e3'))
  union all select public.bottle_open('00000000-0000-4000-8000-000000038122', pg_temp.k('e4'))
  union all select public.bottle_finish(pg_temp.bottle('00000000-0000-4000-8000-000000038122'), pg_temp.k('e5'))
$$, $$ values (pg_temp.action('e1')), (pg_temp.action('e2')), (pg_temp.action('e3')), (pg_temp.action('e4')),
              (pg_temp.action('e5')) $$,
  'each of the five sent again returns its first result');
reset role;
select results_eq($$
  select s.quantity, s.unopened, s.open_count,
         (select count(*) from public.transactions t where t.product_id = s.product_id),
         (select count(*) from public.batches b where b.product_id = s.product_id)
  from public.product_stock s where s.product_id = '00000000-0000-4000-8000-000000038122'
$$, $$ values (4::numeric, 4::numeric, 0, 4::bigint, 3::bigint) $$,
  'and Bonding agent keeps 4 unopened, no open bottle, its 4 ledger rows and its 3 batches');
select pg_temp.act_as('00000000-0000-4000-8000-000000038101');
select throws_ok($$ select public.stock_adjust('00000000-0000-4000-8000-000000038122', 2, 'Expired', null, pg_temp.k('f1')) $$,
  '22023', 'the product is archived', 'a new adjustment of the deleted Bonding agent is still refused');
select throws_ok($$ select pg_temp.add_expiry('L8', 'f2') $$, '22023', 'the product is archived', 'so is a new expiry');
select throws_ok($$ select public.stock_dispose('00000000-0000-4000-8000-000000038132', 1, pg_temp.k('f3')) $$,
  '22023', 'the product is archived', 'a new disposal');
select throws_ok($$ select public.bottle_open('00000000-0000-4000-8000-000000038122', pg_temp.k('f4')) $$,
  '22023', 'the product is archived', 'a new bottle');
select throws_ok($$ select public.bottle_finish(pg_temp.bottle('00000000-0000-4000-8000-000000038122'), pg_temp.k('f5')) $$,
  '22023', 'the product is archived', 'and finishing it again');
reset role;
select is(pg_temp.actions(array['f1', 'f2', 'f3', 'f4', 'f5']), 0::bigint, 'the refusals leave no action behind');
select pg_temp.act_as('00000000-0000-4000-8000-000000038103');
select throws_ok($$ select public.stock_adjust('00000000-0000-4000-8000-000000038122', 6, 'Returned', null, pg_temp.k('e1')) $$,
  '42501', 'not a member of this clinic', 'another clinic''s member sending Sarah''s adjustment again is refused before the lookup');
reset role;

-- Open a new bottle, then Etchant is made countable, then the same open again.
select pg_temp.act_as('00000000-0000-4000-8000-000000038101');
select lives_ok($$ select public.bottle_open('00000000-0000-4000-8000-000000038123', pg_temp.k('01')) $$, 'Sarah opens the one Etchant kit');
select lives_ok($$ select public.bottle_finish(pg_temp.bottle('00000000-0000-4000-8000-000000038123'), pg_temp.k('02')) $$,
  'finishes it');
select lives_ok($$ update public.products set tracking = 'countable' where id = '00000000-0000-4000-8000-000000038123' $$,
  'and makes Etchant countable');
select is(public.bottle_open('00000000-0000-4000-8000-000000038123', pg_temp.k('01')), pg_temp.action('01'),
  'the open sent again returns its first result');
select throws_ok($$ select public.bottle_open('00000000-0000-4000-8000-000000038123', pg_temp.k('03')) $$,
  '22023', 'only multi-use products are opened', 'a new open of the countable Etchant is still refused');
reset role;

-- A read-only clinic is refused on a retry too.
update public.clinics set trial_ends_at = now() - interval '1 day' where id = '00000000-0000-4000-8000-000000038111';
select pg_temp.act_as('00000000-0000-4000-8000-000000038102');
select throws_ok($$ select pg_temp.cancel('a2', 'Logged by mistake', 'c4') $$,
  '42501', 'the clinic is read-only until a payment method is added', 'a read-only clinic cannot cancel the Filling');
select throws_ok($$ select pg_temp.cancel('a1', 'Logged by mistake', 'c1') $$,
  '42501', 'the clinic is read-only until a payment method is added', 'nor send the Root canal''s cancel again');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000038101');
select throws_ok($$ select public.stock_adjust('00000000-0000-4000-8000-000000038122', 6, 'Returned', null, pg_temp.k('e1')) $$,
  '42501', 'the clinic is read-only until a payment method is added', 'nor Sarah her adjustment');
reset role;

select * from finish();
rollback;
