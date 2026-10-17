-- The transactions ledger only grows: no role may update, delete or truncate it, the trigger stops
-- the owner too, and every row's totals add up.
begin;
select plan(14);

insert into auth.users (id, instance_id, aud, role, email)
values ('00000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tap@dentory.test');
insert into public.clinics (id, name, country, currency)
values ('00000000-0000-4000-8000-0000000000c1', 'Smile Dental', 'US', 'USD');
insert into public.products (id, clinic_id, name, unit)
values ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000c1', 'Septocaine 4% 1:100,000', 'cartridges');

select lives_ok($$
  insert into public.transactions (clinic_id, product_id, type, delta, qty_before, qty_after, by_user, ref_type, ref_label, action_id)
  values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', 'count', 2, 0, 2,
          '00000000-0000-4000-8000-000000000001', 'count_session', 'Physical count', gen_random_uuid())
$$, 'a transaction can be written');

select throws_ok($$ update public.transactions set note = 'edited' $$, '23001', null, 'updating the ledger raises');
select throws_ok($$ delete from public.transactions $$, '23001', null, 'deleting from the ledger raises');
select throws_ok($$ truncate public.transactions $$, '23001', null, 'truncating the ledger raises');

select throws_ok($$
  insert into public.transactions (clinic_id, product_id, type, delta, qty_before, qty_after, by_user, ref_type, action_id)
  values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', 'count', 2, 0, 5,
          '00000000-0000-4000-8000-000000000001', 'count_session', gen_random_uuid())
$$, '23514', null, 'qty_after must equal qty_before + delta');

select ok(
  not has_table_privilege(r, 'public.transactions', p),
  r || ' cannot ' || p || ' transactions'
)
from unnest(array['anon', 'authenticated', 'service_role']) as r,
     unnest(array['UPDATE', 'DELETE', 'TRUNCATE']) as p;

select * from finish();
rollback;
