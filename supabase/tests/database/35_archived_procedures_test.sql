-- MS-117 fix (#88) · A past procedure that used a product deleted since: Edit usage lowers it and Cancel procedure gives
-- it back, to its own batches, and the product stays deleted with no alert, To buy line or push; raising it, adding it
-- or taking a new bottle of it is refused and changes nothing; the other stock functions still refuse it; a retry
-- changes nothing and a read-only clinic is refused.
begin;
select plan(39);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000035301', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000035302', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone) values
  ('00000000-0000-4000-8000-000000035311', 'Smile Dental', 'CA', 'CAD', 'America/Toronto');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000035311', '00000000-0000-4000-8000-000000035301', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000035311', '00000000-0000-4000-8000-000000035302', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active');
-- Septocaine stays; Old gauze, Old disinfectant and Old sealer are deleted after the procedures; Old cotton rolls was
-- deleted before any of them.
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target, archived_at) values
  ('00000000-0000-4000-8000-000000035321', '00000000-0000-4000-8000-000000035311', 'Septocaine', 'cartridges', 'countable', 48, 60, null),
  ('00000000-0000-4000-8000-000000035322', '00000000-0000-4000-8000-000000035311', 'Old gauze', 'packs', 'countable', 5, 20, null),
  ('00000000-0000-4000-8000-000000035323', '00000000-0000-4000-8000-000000035311', 'Old disinfectant', 'bottles', 'multi_use', 0, 4, null),
  ('00000000-0000-4000-8000-000000035324', '00000000-0000-4000-8000-000000035311', 'Old sealer', 'kits', 'multi_use', 0, 2, null),
  ('00000000-0000-4000-8000-000000035325', '00000000-0000-4000-8000-000000035311', 'Old cotton rolls', 'packs', 'countable', 0, 10, now());
-- Old gauze in two batches, the one expiring sooner used first.
insert into public.batches (id, clinic_id, product_id, expiry_month, qty) values
  ('00000000-0000-4000-8000-000000035331', '00000000-0000-4000-8000-000000035311', '00000000-0000-4000-8000-000000035321',
   date_trunc('month', current_date + interval '10 months')::date, 50),
  ('00000000-0000-4000-8000-000000035332', '00000000-0000-4000-8000-000000035311', '00000000-0000-4000-8000-000000035322',
   date_trunc('month', current_date + interval '5 months')::date, 4),
  ('00000000-0000-4000-8000-000000035333', '00000000-0000-4000-8000-000000035311', '00000000-0000-4000-8000-000000035322',
   date_trunc('month', current_date + interval '10 months')::date, 6),
  ('00000000-0000-4000-8000-000000035334', '00000000-0000-4000-8000-000000035311', '00000000-0000-4000-8000-000000035323',
   date_trunc('month', current_date + interval '10 months')::date, 3),
  ('00000000-0000-4000-8000-000000035335', '00000000-0000-4000-8000-000000035311', '00000000-0000-4000-8000-000000035324',
   date_trunc('month', current_date + interval '10 months')::date, 1);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.k(p_n text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000000353' || p_n)::uuid
$$;
-- A started procedure's id is its action's id.
create function pg_temp.action(p_key text) returns uuid language sql as $$
  select id from public.stock_actions
  where clinic_id = '00000000-0000-4000-8000-000000035311' and idempotency_key = pg_temp.k(p_key)
$$;
create function pg_temp.items(p_event uuid) returns table (name text, qty numeric, taken_new boolean)
language sql as $$
  select i ->> 'name', (i ->> 'qty')::numeric, (i ->> 'taken_new')::boolean
  from jsonb_array_elements(public.procedure_event_detail(p_event) -> 'items') i
$$;
create function pg_temp.stock(p_product uuid) returns table (quantity numeric, unopened numeric, open_count integer)
language sql as $$ select quantity, unopened, open_count from public.product_stock where product_id = p_product $$;
create function pg_temp.gauze_batches() returns table (qty numeric) language sql as $$
  select qty from public.batches
  where id in ('00000000-0000-4000-8000-000000035332', '00000000-0000-4000-8000-000000035333')
  order by expiry_month
$$;
-- What the deleted products have that a live one would: open alerts, To buy lines and pushes.
create function pg_temp.deleted_extras() returns table (open_alerts bigint, to_buy_lines bigint, pushes bigint)
language sql as $$
  select
    (select count(*) from public.alerts where resolved_at is null and product_id in (
      '00000000-0000-4000-8000-000000035322', '00000000-0000-4000-8000-000000035323', '00000000-0000-4000-8000-000000035324')),
    (select count(*) from public.to_buy_items where status in ('to_buy', 'ordered') and product_id in (
      '00000000-0000-4000-8000-000000035322', '00000000-0000-4000-8000-000000035323', '00000000-0000-4000-8000-000000035324')),
    (select count(*) from public.push_outbox where product_id in (
      '00000000-0000-4000-8000-000000035322', '00000000-0000-4000-8000-000000035323', '00000000-0000-4000-8000-000000035324'))
$$;
-- Root canal's usage as Edit usage sends it, with Old gauze at p_gauze and the bottles taken new.
create function pg_temp.edit_root_canal(p_gauze int, p_take_new uuid[], p_key text, p_extra jsonb default '[]')
returns uuid language sql as $$
  select public.stock_procedure_edit(pg_temp.action('a1'),
    jsonb_build_array(
      jsonb_build_object('product_id', '00000000-0000-4000-8000-000000035321', 'qty', 2),
      jsonb_build_object('product_id', '00000000-0000-4000-8000-000000035322', 'qty', p_gauze),
      jsonb_build_object('product_id', '00000000-0000-4000-8000-000000035323', 'qty', 0),
      jsonb_build_object('product_id', '00000000-0000-4000-8000-000000035324', 'qty', 0)
    ) || p_extra,
    p_take_new, pg_temp.k(p_key))
$$;

-- Michael performs three procedures; Old gauze runs out on the first.
select pg_temp.act_as('00000000-0000-4000-8000-000000035302');
select lives_ok($$
  select public.stock_procedure_start('00000000-0000-4000-8000-000000035311', null, 'Root canal',
    '[{"product_id":"00000000-0000-4000-8000-000000035321","qty":2},
      {"product_id":"00000000-0000-4000-8000-000000035322","qty":10},
      {"product_id":"00000000-0000-4000-8000-000000035323","qty":0},
      {"product_id":"00000000-0000-4000-8000-000000035324","qty":0}]',
    array['00000000-0000-4000-8000-000000035323']::uuid[], pg_temp.k('a1'))
$$, 'a Root canal uses 2 Septocaine and 10 Old gauze and takes a new Old disinfectant');
select lives_ok($$
  select public.stock_procedure_start('00000000-0000-4000-8000-000000035311', null, 'Filling',
    '[{"product_id":"00000000-0000-4000-8000-000000035323","qty":0}]',
    array['00000000-0000-4000-8000-000000035323']::uuid[], pg_temp.k('a2'))
$$, 'a Filling takes another Old disinfectant');
select lives_ok($$
  select public.stock_procedure_start('00000000-0000-4000-8000-000000035311', null, 'Crown',
    '[{"product_id":"00000000-0000-4000-8000-000000035322","qty":1}]', '{}'::uuid[], pg_temp.k('a3'))
$$, 'a Crown uses 1 Old gauze more than there is');
reset role;

-- Sarah deletes the three products.
select pg_temp.act_as('00000000-0000-4000-8000-000000035301');
select lives_ok($$
  select public.product_archive(id) from (values
    ('00000000-0000-4000-8000-000000035322'::uuid), ('00000000-0000-4000-8000-000000035323'::uuid),
    ('00000000-0000-4000-8000-000000035324'::uuid)) v (id)
$$, 'Sarah deletes Old gauze, Old disinfectant and Old sealer');
reset role;
select results_eq($$ select * from pg_temp.deleted_extras() $$, $$ values (0::bigint, 0::bigint, 1::bigint) $$,
  'deleting closed their alerts and took Old gauze off To buy; its Out of stock push was queued before');

-- Edit usage: more of a deleted product is refused, and nothing changes.
select pg_temp.act_as('00000000-0000-4000-8000-000000035302');
select throws_ok($$ select pg_temp.edit_root_canal(11, array['00000000-0000-4000-8000-000000035323']::uuid[], 'b1') $$,
  '22023', 'Old gauze was deleted. Its usage can go down, not up.', 'a deleted product''s usage cannot go up');
select throws_ok($$
  select pg_temp.edit_root_canal(10, array['00000000-0000-4000-8000-000000035323']::uuid[], 'b2',
    '[{"product_id":"00000000-0000-4000-8000-000000035325","qty":1}]')
$$, '22023', 'Old cotton rolls was deleted. Its usage can go down, not up.', 'nor can a deleted product be added');
select throws_ok($$
  select pg_temp.edit_root_canal(10, array['00000000-0000-4000-8000-000000035323', '00000000-0000-4000-8000-000000035324']::uuid[], 'b3')
$$, '22023', 'Old sealer was deleted. No new bottle can be opened for it.', 'nor a new bottle of one taken');
reset role;
select results_eq($$ select * from pg_temp.gauze_batches() $$, $$ values (0::numeric), (0::numeric) $$,
  'the refusals left Old gauze''s batches as they were');
select results_eq($$ select * from pg_temp.items(pg_temp.action('a1')) $$,
  $$ values ('Old disinfectant', 0::numeric, true), ('Old gauze', 10::numeric, false), ('Old sealer', 0::numeric, false),
            ('Septocaine', 2::numeric, false) $$,
  'and the record as it was');
select is((select count(*) from public.stock_actions where idempotency_key in (pg_temp.k('b1'), pg_temp.k('b2'), pg_temp.k('b3'))),
  0::bigint, 'a refused edit leaves no action behind');

-- Edit usage: Old gauze down from 10 to 4.
select is((select count(*) from public.alerts where resolved_at is null and kind = 'low'
  and product_id = '00000000-0000-4000-8000-000000035321'), 1::bigint, 'Septocaine is Low after the Root canal');
select pg_temp.act_as('00000000-0000-4000-8000-000000035302');
select lives_ok($$ select pg_temp.edit_root_canal(4, array['00000000-0000-4000-8000-000000035323']::uuid[], 'b4') $$,
  'Michael lowers Old gauze from 10 to 4');
reset role;
select is((select count(*) from public.transactions where action_id = pg_temp.action('b4')), 1::bigint,
  'the edit writes one transaction');
select results_eq($$ select * from pg_temp.gauze_batches() $$, $$ values (0::numeric), (6::numeric) $$,
  'the 6 go back to the batch they were taken from last');
select ok((select archived_at is not null from public.products where id = '00000000-0000-4000-8000-000000035322'),
  'Old gauze stays deleted');
select results_eq($$ select * from pg_temp.deleted_extras() $$, $$ values (0::bigint, 0::bigint, 1::bigint) $$,
  'with no alert, no To buy line and no push');
select results_eq($$ select * from pg_temp.items(pg_temp.action('a1')) $$,
  $$ values ('Old disinfectant', 0::numeric, true), ('Old gauze', 4::numeric, false), ('Old sealer', 0::numeric, false),
            ('Septocaine', 2::numeric, false) $$,
  'the record says 4');

-- A retry of the same edit changes nothing.
select pg_temp.act_as('00000000-0000-4000-8000-000000035302');
select is(pg_temp.edit_root_canal(0, '{}'::uuid[], 'b4'), pg_temp.action('b4'), 'a retry returns the first action');
reset role;
select results_eq($$ select * from pg_temp.gauze_batches() $$, $$ values (0::numeric), (6::numeric) $$,
  'and gives nothing more back');

-- Edit usage: Old disinfectant's new bottle given back, Old sealer off the record.
select pg_temp.act_as('00000000-0000-4000-8000-000000035302');
select lives_ok($$
  select public.stock_procedure_edit(pg_temp.action('a1'),
    '[{"product_id":"00000000-0000-4000-8000-000000035321","qty":2},
      {"product_id":"00000000-0000-4000-8000-000000035322","qty":4},
      {"product_id":"00000000-0000-4000-8000-000000035323","qty":0}]',
    '{}'::uuid[], pg_temp.k('b5'))
$$, 'Michael gives back the deleted Old disinfectant''s new bottle and takes Old sealer off');
reset role;
select results_eq($$ select * from pg_temp.stock('00000000-0000-4000-8000-000000035323') $$,
  $$ values (3::numeric, 2::numeric, 1) $$, 'the bottle is back unopened');
select results_eq($$ select * from pg_temp.items(pg_temp.action('a1')) $$,
  $$ values ('Old disinfectant', 0::numeric, false), ('Old gauze', 4::numeric, false), ('Septocaine', 2::numeric, false) $$,
  'and the record follows');

-- Cancel procedure gives back every product, deleted ones included.
select pg_temp.act_as('00000000-0000-4000-8000-000000035302');
select lives_ok($$ select public.stock_procedure_cancel(pg_temp.action('a1'), 'Logged by mistake', pg_temp.k('c1')) $$,
  'Michael cancels the Root canal');
reset role;
select results_eq($$ select * from pg_temp.gauze_batches() $$, $$ values (4::numeric), (6::numeric) $$,
  'Old gauze''s last 4 are back in the batch they came from');
select is((select quantity from public.product_stock where product_id = '00000000-0000-4000-8000-000000035321'), 50::numeric,
  'Septocaine''s 2 are back');
select is((select count(*) from public.alerts where resolved_at is null and kind = 'low'
  and product_id = '00000000-0000-4000-8000-000000035321'), 0::bigint, 'and its Low alert closes: a live product is refreshed');
select results_eq($$ select * from pg_temp.deleted_extras() $$, $$ values (0::bigint, 0::bigint, 1::bigint) $$,
  'the deleted products get no alert, To buy line or push');
select is((select count(*) from public.products where archived_at is null and id in (
  '00000000-0000-4000-8000-000000035322', '00000000-0000-4000-8000-000000035323', '00000000-0000-4000-8000-000000035324')),
  0::bigint, 'and stay deleted');
select pg_temp.act_as('00000000-0000-4000-8000-000000035302');
select lives_ok($$ select public.stock_procedure_cancel(pg_temp.action('a2'), 'Patient cancelled', pg_temp.k('c2')) $$,
  'Michael cancels the Filling');
reset role;
select results_eq($$ select * from pg_temp.stock('00000000-0000-4000-8000-000000035323') $$,
  $$ values (3::numeric, 3::numeric, 0) $$, 'the deleted Old disinfectant''s bottle it opened is back unopened');

-- Everything else still refuses a deleted product.
select pg_temp.act_as('00000000-0000-4000-8000-000000035301');
select throws_ok($$ select public.stock_adjust('00000000-0000-4000-8000-000000035322', 5, 'Physical count', null, pg_temp.k('d1')) $$,
  '22023', 'the product is archived', 'Adjust refuses a deleted product');
select throws_ok($$ select public.stock_count_apply('00000000-0000-4000-8000-000000035311',
  '[{"product_id":"00000000-0000-4000-8000-000000035322","counted":5}]', pg_temp.k('d2')) $$,
  '22023', 'the product is archived', 'so does a count');
select throws_ok($$ select public.stock_receive('00000000-0000-4000-8000-000000035311',
  '[{"product_id":"00000000-0000-4000-8000-000000035322","qty":5}]', pg_temp.k('d3')) $$,
  '22023', 'the product is archived', 'receiving');
select throws_ok($$ select public.stock_procedure_start('00000000-0000-4000-8000-000000035311', null, 'Root canal',
  '[{"product_id":"00000000-0000-4000-8000-000000035322","qty":1}]', '{}'::uuid[], pg_temp.k('d4')) $$,
  '22023', 'the product is archived', 'starting a procedure');
select throws_ok($$ select public.bottle_open('00000000-0000-4000-8000-000000035323', pg_temp.k('d5')) $$,
  '22023', 'the product is archived', 'opening a bottle');
select throws_ok($$ select public.stock_dispose('00000000-0000-4000-8000-000000035333', 1, pg_temp.k('d6')) $$,
  '22023', 'the product is archived', 'and Mark disposed');
reset role;

-- A read-only clinic cannot edit or cancel.
update public.clinics set trial_ends_at = now() - interval '1 day' where id = '00000000-0000-4000-8000-000000035311';
select pg_temp.act_as('00000000-0000-4000-8000-000000035302');
select throws_ok($$ select public.stock_procedure_edit(pg_temp.action('a3'), '[]', '{}'::uuid[], pg_temp.k('e1')) $$,
  '42501', 'the clinic is read-only until a payment method is added', 'a read-only clinic cannot edit the Crown');
select throws_ok($$ select public.stock_procedure_cancel(pg_temp.action('a3'), 'Logged by mistake', pg_temp.k('e2')) $$,
  '42501', 'the clinic is read-only until a payment method is added', 'nor cancel it');
reset role;

select * from finish();
rollback;
