-- Status rules (PRD §5): the same 14 cases as ProductStatusTests.swift, then the views, the month-end
-- expiry rule and the daily re-evaluation that flips a product to Expiring as time passes.
begin;
select plan(34);

-- The rule table (tracking, quantity, unopened, minimum, missing, days, threshold → status) ----------
select is(public.evaluate_product_status(t, q, u, m, x, d, th), expected, name)
from (values
  ('countable, plenty, dated far away',                 'countable'::public.tracking_mode, 54, 54, 20, 0, 200, 90, 'healthy'),
  ('countable at zero',                                 'countable', 0, 0, 3, 0, null, 90, 'out_of_stock'),
  ('countable negative (shortfall)',                    'countable', -2, -2, 3, 0, null, 90, 'out_of_stock'),
  ('countable at the minimum',                          'countable', 20, 20, 20, 0, 200, 90, 'low'),
  ('countable low beats expiring',                      'countable', 2, 2, 3, 0, 10, 90, 'low'),
  ('countable expiring inside the window',              'countable', 54, 54, 20, 0, 60, 90, 'expiring'),
  ('countable expiring on the last day of the window',  'countable', 54, 54, 20, 0, 90, 90, 'expiring'),
  ('countable just outside the window',                 'countable', 54, 54, 20, 0, 91, 90, 'healthy'),
  ('countable with an expired batch',                   'countable', 54, 54, 20, 0, -5, 90, 'expiring'),
  ('countable expiring beats missing expiry',           'countable', 54, 54, 20, 3, 60, 90, 'expiring'),
  ('countable with undated stock only',                 'countable', 54, 54, 20, 54, null, 90, 'missing_expiry'),
  ('multi-use with one open and none unopened',         'multi_use', 1, 0, 1, 0, null, 90, 'low'),
  ('multi-use with nothing open or unopened',           'multi_use', 0, 0, 1, 0, null, 90, 'out_of_stock'),
  ('narrow threshold set keeps a 60-day batch healthy', 'countable', 54, 54, 20, 0, 60, 30, 'healthy')
) as cases(name, t, q, u, m, x, d, th, expected);

-- Month-end expiry in the clinic's time zone ---------------------------------------------------------
select is(public.days_to_expiry(date_trunc('month', current_date)::date, 'UTC'),
  ((date_trunc('month', current_date) + interval '1 month' - interval '1 day')::date - current_date), 'a batch expires on the last day of its month');
select is(public.days_to_expiry(null, 'UTC'), null, 'no expiry, no days');

-- Views and the daily refresh ----------------------------------------------------------------------
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin1@medisave.test');
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-0000000000c1', 'Smile Dental', 'US', 'USD', 'America/New_York', '{90}');
insert into public.memberships (clinic_id, user_id, email, role, status) values
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', 'admin1@medisave.test', 'admin', 'active');
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target, last_unit_cost) values
  ('00000000-0000-4000-8000-0000000000d1', '00000000-0000-4000-8000-0000000000c1', 'Septocaine 4% 1:100,000', 'cartridges', 'countable', 20, 60, 2.00),
  ('00000000-0000-4000-8000-0000000000d2', '00000000-0000-4000-8000-0000000000c1', 'Bonding agent', 'bottles', 'multi_use', 1, 3, 30.00),
  ('00000000-0000-4000-8000-0000000000d3', '00000000-0000-4000-8000-0000000000c1', 'Nitrile gloves M', 'boxes', 'countable', 3, 10, 8.00);
-- Septocaine: 50 dated five months out, 4 undated. Bonding: 2 unopened dated far out, 1 open. Gloves: nothing.
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d1', date_trunc('month', current_date + interval '5 months')::date, 'A112', 50),
  ('00000000-0000-4000-8000-0000000000e3', '00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d1', null, null, 4),
  ('00000000-0000-4000-8000-0000000000e4', '00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d2', date_trunc('month', current_date + interval '8 months')::date, 'BA7', 2);
insert into public.open_items (clinic_id, product_id, opened_by) values
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d2', '00000000-0000-4000-8000-0000000000a1');
select public.refresh_all_products();

select is(status, 'missing_expiry', 'Septocaine: undated stock, nothing expiring yet') from public.product_status where product_id = '00000000-0000-4000-8000-0000000000d1';
select is(value, 108.00::numeric, 'Septocaine value is quantity times last unit cost') from public.product_status where product_id = '00000000-0000-4000-8000-0000000000d1';
select is(status, 'healthy', 'Bonding: 2 unopened above its minimum of 1') from public.product_status where product_id = '00000000-0000-4000-8000-0000000000d2';
select is(open_count, 1, 'Bonding: one open bottle') from public.product_status where product_id = '00000000-0000-4000-8000-0000000000d2';
select is(status, 'out_of_stock', 'Gloves: nothing in stock') from public.product_status where product_id = '00000000-0000-4000-8000-0000000000d3';
select is(days_to_soonest_expiry, null, 'Gloves: no expiry to count down') from public.product_status where product_id = '00000000-0000-4000-8000-0000000000d3';

select is(to_buy_count, 1, 'attention: one To buy line (gloves, auto-added)') from public.clinic_attention where clinic_id = '00000000-0000-4000-8000-0000000000c1';
select is(expiring_batch_count, 0, 'attention: nothing expiring within 90 days') from public.clinic_attention where clinic_id = '00000000-0000-4000-8000-0000000000c1';
select is(missing_expiry_product_count, 1, 'attention: one product with undated stock') from public.clinic_attention where clinic_id = '00000000-0000-4000-8000-0000000000c1';
select is(inventory_value, 198.00::numeric, 'attention: inventory value sums every product') from public.clinic_attention where clinic_id = '00000000-0000-4000-8000-0000000000c1';
select is(value_at_risk_90, 0.00::numeric, 'attention: nothing at risk yet') from public.clinic_attention where clinic_id = '00000000-0000-4000-8000-0000000000c1';

-- Time passes: the batch enters the 90-day window; the daily job notices without any transaction.
update public.batches set expiry_month = date_trunc('month', current_date + interval '1 month')::date where id = '00000000-0000-4000-8000-0000000000e1';
select is(status, 'expiring', 'the view sees the batch inside the window at once') from public.product_status where product_id = '00000000-0000-4000-8000-0000000000d1';
select is((select count(*) from public.alerts where product_id = '00000000-0000-4000-8000-0000000000d1' and kind = 'expiring' and resolved_at is null), 0::bigint, 'but no alert exists until the refresh runs');
select is(public.refresh_all_products(), 3, 'the daily refresh visits every active product');
select is((select count(*) from public.alerts where product_id = '00000000-0000-4000-8000-0000000000d1' and kind = 'expiring' and resolved_at is null), 1::bigint, 'and opens one expiring alert (the clinic has the 90-day threshold only)');
select is(expiring_batch_count, 1, 'attention: one expiring batch') from public.clinic_attention where clinic_id = '00000000-0000-4000-8000-0000000000c1';
select is(value_at_risk_90, 100.00::numeric, 'attention: its value is at risk') from public.clinic_attention where clinic_id = '00000000-0000-4000-8000-0000000000c1';
select is((select schedule from cron.job where jobname = 'refresh-product-status'), '0 7 * * *', 'the refresh is scheduled daily at 07:00 UTC');

select * from finish();
rollback;
