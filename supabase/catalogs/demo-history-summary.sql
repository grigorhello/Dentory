-- What the clinic __CLINIC_ID__ reads once make seed-demo-history has run (demo-history.sh prints it): Home's tiles,
-- the catalog products by status, To buy, Expiring soon, Missing expiry, the history's span and what was archived. Read
-- only; one line per row.
with
  clinic as (select c.id, c.time_zone from public.clinics c where c.id = '__CLINIC_ID__'),
  products as (
    select p.name, p.unit, p.archived_at, s.status
    from public.products p join clinic c on c.id = p.clinic_id
    join public.product_status s on s.product_id = p.id
  ),
  latest as (
    select e.name, e.started_at, coalesce(nullif(m.full_name, ''), m.email) as by_name
    from public.procedure_events e join clinic c on c.id = e.clinic_id
    left join public.memberships m on m.clinic_id = e.clinic_id and m.user_id = e.started_by
    where e.cancelled_at is null
    order by e.started_at desc
    limit 1
  )
select line
from (
  select 1 as n, format('Home: %s To buy, %s Expiring soon, %s Missing expiry; Inventory value $%s, at risk within 90 days $%s.',
           a.to_buy_count, a.expiring_batch_count, a.missing_expiry_product_count,
           to_char(round(a.inventory_value), 'FM999,999,990'), to_char(round(a.value_at_risk_90), 'FM999,999,990')) as line
  from public.clinic_attention a join clinic c on c.id = a.clinic_id
  union all
  select 2, format('Products: %s Healthy, %s Low, %s Out of stock, %s Expiring, %s Missing expiry.',
           count(*) filter (where status = 'healthy'), count(*) filter (where status = 'low'),
           count(*) filter (where status = 'out_of_stock'), count(*) filter (where status = 'expiring'),
           count(*) filter (where status = 'missing_expiry'))
  from products where archived_at is null
  union all
  select 3, 'To buy: ' || coalesce(string_agg(format('%s (%s %s)', p.name, trim_scale(t.qty), p.unit), ', ' order by p.name)
           filter (where t.status = 'to_buy'), 'nothing')
         || '. Ordered: ' || coalesce(string_agg(format('%s (%s %s)', p.name, trim_scale(t.qty), p.unit), ', ' order by p.name)
           filter (where t.status = 'ordered'), 'nothing') || '.'
  from public.to_buy_items t join clinic c on c.id = t.clinic_id join public.products p on p.id = t.product_id
  where t.status in ('to_buy', 'ordered')
  union all
  select 4, 'Expiring soon: ' || coalesce(string_agg(format('%s, %s %s, lot %s, %s', p.name, trim_scale(b.qty), p.unit,
           coalesce(b.lot, 'none'), to_char(b.expiry_month, 'Mon YYYY')), '; ' order by b.expiry_month, p.name), 'nothing') || '.'
  from public.batches b join clinic c on c.id = b.clinic_id join public.products p on p.id = b.product_id
  where p.archived_at is null and b.qty > 0 and b.expiry_month is not null
    and public.days_to_expiry(b.expiry_month, c.time_zone)
      <= (select max(t) from public.clinics x cross join unnest(x.expiry_thresholds) t where x.id = c.id)
  union all
  select 5, 'Missing expiry: ' || coalesce(string_agg(name, ', ' order by name), 'nothing') || '.'
  from products where archived_at is null and status = 'missing_expiry'
  union all
  select 6, format('History: %s procedures and %s ledger rows from %s to %s; latest procedure %s, %s, by %s.',
           (select to_char(count(*), 'FM999,999,990') from public.procedure_events e join clinic c on c.id = e.clinic_id),
           (select to_char(count(*), 'FM999,999,990') from public.transactions t join clinic c on c.id = t.clinic_id),
           (select to_char(min(t.at at time zone c.time_zone), 'Dy YYYY-MM-DD') from public.transactions t join clinic c on c.id = t.clinic_id),
           (select to_char(max(t.at at time zone c.time_zone), 'Dy YYYY-MM-DD') from public.transactions t join clinic c on c.id = t.clinic_id),
           l.name, to_char(l.started_at at time zone c.time_zone, 'Dy YYYY-MM-DD HH24:MI'), l.by_name)
  from latest l cross join clinic c
  union all
  select 7, 'Archived: ' || string_agg(name, ', ' order by name) || '.'
  from products where archived_at is not null
  having count(*) > 0
) lines
order by n;
