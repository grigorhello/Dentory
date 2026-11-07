-- `make catalog-check` (check.sh), after the catalog ran twice on clinic A, a clinic made the way sign-up makes one.
-- Variables: clinic (A), admin (its admin), products (the catalog's product count), categories (A's categories once
-- the catalog has run: the ten defaults plus any the catalog brings). Stops with the reason when something is off;
-- otherwise prints what the clinic holds, then what the nightly status refresh, two first counts and a first delivery
-- do to it, in a transaction rolled back at the end.

create temp table check_args as
select :'clinic'::uuid as clinic, :'admin'::uuid as admin, :products::integer as products,
  :categories::integer as categories;

-- What the catalog wrote ---------------------------------------------------------------------------------------------

do $$
declare
  c uuid;
  n integer;
  v_categories integer;
  v_count integer;
  v_wrong text;
begin
  select clinic, products, categories into c, n, v_categories from check_args;

  -- Each catalog product once, in categories of its own clinic.
  select count(*) into v_count from public.products where clinic_id = c;
  if v_count <> n then
    raise exception 'The clinic has % products; the catalog has %', v_count, n;
  end if;
  if (select count(distinct lower(name)) from public.products where clinic_id = c) <> n then
    raise exception 'Two products share a name';
  end if;
  select count(*) into v_count from public.categories where clinic_id = c;
  if v_count <> v_categories then
    raise exception 'The clinic has % categories; % were expected', v_count, v_categories;
  end if;

  -- As New product writes a product (MS-117): trimmed name, a counted-in unit, a pack with a size of 2 or more or no
  -- pack, the target at least the minimum, a category; nothing the clinic fills itself (supplier, location, the cost
  -- receiving sets), not archived, no To buy suggestion held back.
  select string_agg(p.name, ', ' order by p.created_at) into v_wrong
  from public.products p
  where p.clinic_id = c and not (
    p.name = btrim(p.name) and length(p.name) between 1 and 120
    and p.unit = lower(btrim(p.unit)) and length(p.unit) between 1 and 40
    and (p.pack_unit is null and p.pack_size is null
         or p.pack_unit = lower(btrim(p.pack_unit)) and p.pack_unit <> '' and p.pack_size >= 2)
    and p.minimum >= 0 and p.target >= p.minimum and p.target > 0
    and p.supplier is null and p.location is null and p.last_unit_cost is null
    and p.archived_at is null and not p.to_buy_dismissed
    and exists (select 1 from public.categories k where k.id = p.category_id and k.clinic_id = c)
  );
  if v_wrong is not null then
    raise exception 'These products are not written as New product writes one: %', v_wrong;
  end if;

  -- One millisecond apart, so the order they joined the clinic (To buy's order) is the catalog's.
  if (select count(distinct created_at) from public.products where clinic_id = c) <> n then
    raise exception 'Products share a creation time, so To buy would list them in no set order';
  end if;

  -- Every product at 0, which Inventory shows as Out of stock (the status is worked out as it is read).
  select string_agg(p.name, ', ') into v_wrong
  from public.products p
  join public.product_status s on s.product_id = p.id
  where p.clinic_id = c
    and (s.status <> 'out_of_stock' or s.quantity <> 0 or s.unopened <> 0 or s.open_count <> 0
         or s.missing_expiry_qty <> 0 or s.value <> 0);
  if v_wrong is not null then
    raise exception 'These products do not start at 0, Out of stock: %', v_wrong;
  end if;

  -- Nothing but the catalog: no stock, ledger rows, open bottles, To buy lines, alerts or pushes.
  if exists (select 1 from public.batches where clinic_id = c)
     or exists (select 1 from public.transactions where clinic_id = c)
     or exists (select 1 from public.open_items where clinic_id = c)
     or exists (select 1 from public.stock_actions where clinic_id = c)
     or exists (select 1 from public.to_buy_items where clinic_id = c)
     or exists (select 1 from public.alerts where clinic_id = c)
     or exists (select 1 from public.push_outbox where clinic_id = c)
  then
    raise exception 'The catalog wrote stock, ledger, open bottle, To buy, alert or push rows';
  end if;
end;
$$;

-- What the admin reads, through the app's own calls and the clinic's policies -------------------------------------

begin;
select set_config('request.jwt.claims', json_build_object('sub', admin, 'role', 'authenticated')::text, true),
  set_config('check.clinic', clinic::text, true), set_config('check.products', products::text, true)
from check_args \gset
set local role authenticated;
do $$
declare
  c uuid := current_setting('check.clinic')::uuid;
  n integer := current_setting('check.products')::integer;
begin
  if (select count(*) from public.inventory_list(c) where status = 'out_of_stock') <> n then
    raise exception 'Inventory does not list every product as Out of stock';
  end if;
  if (select count(*) from public.receive_products(c)) <> n then
    raise exception 'Receive manually does not offer every product';
  end if;
  if (select to_buy_count from public.clinic_attention where clinic_id = c) <> 0
     or (select inventory_value from public.clinic_attention where clinic_id = c) <> 0
     or public.alerts_unseen(c)
  then
    raise exception 'Home shows To buy lines, stock value or unseen alerts before any refresh';
  end if;
end;
$$;
commit;

\echo
\echo 'The catalog on a new clinic: each product once, at 0 and Out of stock, nothing else written'
select k.name as "Category", count(p.id) as "Products",
  count(p.id) filter (where p.tracking = 'multi_use') as "Multi-use",
  count(p.id) filter (where p.pack_unit is not null) as "With a pack"
from public.categories k
join check_args a on k.clinic_id = a.clinic
left join public.products p on p.category_id = k.id
group by k.name, k.position
order by k.position;

-- What happens next, rolled back at the end --------------------------------------------------------------------------

begin;
create temp table check_after (step integer, what text, value text) on commit drop;

-- The nightly status refresh (pg_cron, 07:00 UTC) leaves products never stocked alone: no alert, no push, no To buy
-- line (20261107063703_no_alerts_before_first_stock.sql), though Inventory shows each at 0, Out of stock.
select public.refresh_all_products() is not null as refreshed \gset
do $$
declare
  c uuid := (select clinic from check_args);
begin
  if exists (select 1 from public.alerts where clinic_id = c)
     or exists (select 1 from public.push_outbox where clinic_id = c)
     or exists (select 1 from public.to_buy_items where clinic_id = c)
  then
    raise exception 'The refresh raised alerts, pushes or To buy lines for products never stocked';
  end if;
  if exists (select 1 from public.product_status where clinic_id = c and status <> 'out_of_stock') then
    raise exception 'After the refresh, not every product reads Out of stock';
  end if;
  insert into check_after
  select 1, 'Alerts', (select count(*)::text from public.alerts where clinic_id = c)
  union all
  select 2, 'Pushes queued', (select count(*)::text from public.push_outbox where clinic_id = c)
  union all
  select 3, 'To buy lines', (select count(*)::text from public.to_buy_items where clinic_id = c);
end;
$$;

-- Then the admin counts the first two countable products: the first above its minimum, the second at it. No expiry
-- date comes with a count (MS-100 D9), so the first reads Missing expiry, with nothing to buy; the second reads Low,
-- with its Low alert and an automatic To buy line for its target less the count, as for any product once stocked.
select set_config('request.jwt.claims', json_build_object('sub', admin, 'role', 'authenticated')::text, true)
from check_args \gset
create temp table check_counted on commit drop as
select k.id, k.name, k.target, k.counted, k.place
from (
  select p.id, p.name, p.target, row_number() over (order by p.created_at) as place,
    case when row_number() over (order by p.created_at) = 1 then ceil((p.minimum + p.target) / 2) else p.minimum end
      as counted
  from public.products p, check_args a
  where p.clinic_id = a.clinic and p.tracking = 'countable' and p.minimum >= 1
) k
where k.place <= 2;
select public.stock_count_apply(a.clinic,
  (select jsonb_agg(jsonb_build_object('product_id', k.id, 'counted', k.counted) order by k.place) from check_counted k),
  gen_random_uuid()) is not null as counted
from check_args a \gset
do $$
declare
  k record;
begin
  select * into k from check_counted where place = 1;
  if (select status from public.product_status where product_id = k.id) <> 'missing_expiry'
     or exists (select 1 from public.alerts where product_id = k.id and kind in ('out_of_stock', 'low'))
     or not exists (select 1 from public.alerts where product_id = k.id and kind = 'missing_expiry' and resolved_at is null)
     or exists (select 1 from public.to_buy_items where product_id = k.id)
  then
    raise exception '% does not read Missing expiry, with its alert and nothing to buy, after its first count', k.name;
  end if;
  insert into check_after
  select 4, 'After counting ' || k.name || ' at ' || trim_scale(k.counted), 'missing_expiry, no To buy line';

  select * into k from check_counted where place = 2;
  if (select status from public.product_status where product_id = k.id) <> 'low'
     or not exists (select 1 from public.alerts where product_id = k.id and kind = 'low' and resolved_at is null)
     or not exists (select 1 from public.to_buy_items
                    where product_id = k.id and source = 'auto' and status = 'to_buy'
                      and qty = greatest(k.target - k.counted, 1))
  then
    raise exception '% does not read Low, with its alert and its To buy line, after a first count at its minimum', k.name;
  end if;
  insert into check_after
  select 5, 'After counting ' || k.name || ' at ' || trim_scale(k.counted),
    (select 'low, To buy line of ' || t.qty::integer from public.to_buy_items t
     where t.product_id = k.id and t.status = 'to_buy');
end;
$$;

-- And receives the next countable product up to its target, with an expiry date: Healthy, nothing raised.
create temp table check_received on commit drop as
select p.id, p.name, p.target
from public.products p, check_args a
where p.clinic_id = a.clinic and p.tracking = 'countable' and p.id not in (select id from check_counted)
order by p.created_at
limit 1;
select public.stock_receive(a.clinic,
  jsonb_build_array(jsonb_build_object('product_id', r.id, 'qty', r.target,
    'expiry_month', date_trunc('month', now() + interval '2 years')::date)),
  gen_random_uuid(), 'manual', null, 'Opening stock') is not null as received
from check_args a, check_received r \gset
do $$
declare
  r record;
begin
  select * into r from check_received;
  if (select status from public.product_status where product_id = r.id) <> 'healthy'
     or exists (select 1 from public.to_buy_items where product_id = r.id)
     or exists (select 1 from public.alerts where product_id = r.id and resolved_at is null)
  then
    raise exception '% is not Healthy, with no alert and nothing to buy, after its first delivery', r.name;
  end if;
  insert into check_after select 6, 'After receiving ' || r.name || ' up to ' || trim_scale(r.target), 'healthy, no To buy line';
end;
$$;

\echo 'Then, rolled back: the nightly status refresh, two first counts and a first delivery'
select what as "Step", value as "Result" from check_after order by step;
rollback;
