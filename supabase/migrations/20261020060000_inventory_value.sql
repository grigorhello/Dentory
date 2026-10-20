-- MS-135 · Inventory value (PRD §5 Inventory value, Appendix B value; f10, built as drawn: MS-100 D7).
-- One security invoker read for the screen, so RLS keeps each clinic to itself. Every figure is at the product's
-- last unit cost, and a product without a cost counts as 0:
-- - total and at_risk_90: Home's "Inventory value" and "At risk, 90 days" tiles, read from clinic_attention so
--   the screen and the tiles always agree;
-- - used_30: what the procedures started in the last 30 days and not cancelled took from stock: their supplies
--   plus the bottles they opened, archived products included;
-- - received_30: what was received in the last 30 days, net of an Undo (its rows keep the receiving type);
-- - uncosted_count: active products in stock without a cost, which the total leaves out;
-- - categories: the active products' value by category, largest first, leaving out categories worth nothing; a
--   product without a category is grouped under a null id and name;
-- - top_products: the five most valuable active products.
create function public.inventory_value(p_clinic_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with active as (
    select p.id, p.name, p.unit, p.category_id, p.last_unit_cost, s.quantity, s.value
    from public.products p
    join public.product_status s on s.product_id = p.id
    where p.clinic_id = p_clinic_id and p.archived_at is null
  ),
  attention as (
    select a.inventory_value, a.value_at_risk_90 from public.clinic_attention a where a.clinic_id = p_clinic_id
  ),
  recent_events as (
    select e.id from public.procedure_events e
    where e.clinic_id = p_clinic_id and e.cancelled_at is null and e.started_at >= now() - interval '30 days'
  ),
  by_category as (
    select a.category_id, c.name, sum(a.value)::numeric(14, 2) as value, count(*)::integer as product_count
    from active a
    left join public.categories c on c.id = a.category_id
    group by a.category_id, c.name
    having sum(a.value) > 0
  ),
  top_five as (
    select a.id, a.name, a.unit, a.quantity, a.last_unit_cost, a.value
    from active a
    where a.value > 0
    order by a.value desc, lower(a.name), a.id
    limit 5
  )
  select jsonb_build_object(
    'total', coalesce((select inventory_value from attention), 0),
    'at_risk_90', coalesce((select value_at_risk_90 from attention), 0),
    'used_30', (
      (select coalesce(sum(i.qty * coalesce(p.last_unit_cost, 0)), 0)
         from public.procedure_event_items i
         join recent_events e on e.id = i.event_id
         join public.products p on p.id = i.product_id)
      + (select coalesce(sum(coalesce(p.last_unit_cost, 0)), 0)
           from public.procedure_event_openings o
           join recent_events e on e.id = o.event_id
           join public.products p on p.id = o.product_id)
    )::numeric(14, 2),
    'received_30', (
      select coalesce(sum(t.delta * coalesce(p.last_unit_cost, 0)), 0)
      from public.transactions t
      join public.products p on p.id = t.product_id
      where t.clinic_id = p_clinic_id and t.type = 'receiving' and t.at >= now() - interval '30 days'
    )::numeric(14, 2),
    'uncosted_count', (select count(*) from active a where a.last_unit_cost is null and a.quantity > 0),
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
          'category_id', b.category_id, 'name', b.name, 'value', b.value, 'product_count', b.product_count
        ) order by b.value desc, lower(b.name) nulls last)
      from by_category b
    ), '[]'::jsonb),
    'top_products', coalesce((
      select jsonb_agg(jsonb_build_object(
          'product_id', t.id, 'name', t.name, 'unit', t.unit, 'quantity', t.quantity, 'unit_cost', t.last_unit_cost,
          'value', t.value
        ) order by t.value desc, lower(t.name), t.id)
      from top_five t
    ), '[]'::jsonb)
  );
$$;
revoke execute on function public.inventory_value(uuid) from public, anon;
grant execute on function public.inventory_value(uuid) to authenticated, service_role;
