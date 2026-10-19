-- MS-116 · Product detail in one query (PRD §6.4): the product with its figures and status, what procedures
-- used in the last 30 days (net of usage edited down and of cancellations, which the engine writes as
-- positive procedure and cancellation rows), when it was last counted, whether it is on the To buy list,
-- its batches, its open bottles and the last 20 ledger rows with who wrote them. Security invoker: the policies on
-- products, the stock tables and the ledger decide what the caller sees; a product of another clinic, or
-- an archived one, comes back with a null "product".
create function public.product_detail(p_product_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'product', (
      select jsonb_build_object(
        'id', p.id, 'name', p.name, 'category_name', c.name, 'unit', p.unit, 'pack_unit', p.pack_unit,
        'pack_size', p.pack_size, 'minimum', p.minimum, 'target', p.target, 'tracking', p.tracking,
        'location', p.location, 'status', s.status, 'quantity', s.quantity, 'unopened', s.unopened,
        'open_count', s.open_count, 'missing_expiry_qty', s.missing_expiry_qty
      )
      from public.products p
      join public.product_status s on s.product_id = p.id
      left join public.categories c on c.id = p.category_id
      where p.id = p_product_id and p.archived_at is null
    ),
    'used_in_30_days', (
      select greatest(coalesce(-sum(t.delta), 0), 0)
      from public.transactions t
      where t.product_id = p_product_id and t.type in ('procedure', 'cancellation')
        and t.at >= now() - interval '30 days'
    ),
    'last_counted_at', (
      select max(t.at) from public.transactions t where t.product_id = p_product_id and t.type = 'count'
    ),
    'to_buy_item_id', (
      select t.id from public.to_buy_items t
      where t.product_id = p_product_id and t.status in ('to_buy', 'ordered')
      order by t.created_at desc
      limit 1
    ),
    'batches', (
      select coalesce(jsonb_agg(
        jsonb_build_object('id', b.id, 'expiry_month', b.expiry_month, 'lot', b.lot, 'qty', b.qty)
        order by b.expiry_month asc nulls last, b.created_at asc
      ), '[]'::jsonb)
      from public.batches b
      where b.product_id = p_product_id and b.qty <> 0
    ),
    'open_items', (
      select coalesce(jsonb_agg(
        jsonb_build_object('id', o.id, 'opened_at', o.opened_at, 'opened_by_name', coalesce(m.full_name, ''))
        order by o.opened_at desc
      ), '[]'::jsonb)
      from public.open_items o
      left join public.memberships m on m.user_id = o.opened_by and m.clinic_id = o.clinic_id
      where o.product_id = p_product_id and o.finished_at is null
    ),
    'history', (
      select coalesce(jsonb_agg(to_jsonb(h) order by h.at desc), '[]'::jsonb)
      from (
        select t.id, t.type, t.delta, t.qty_before, t.qty_after, t.reason, t.ref_label, t.at,
               coalesce(m.full_name, '') as by_name
        from public.transactions t
        left join public.memberships m on m.user_id = t.by_user and m.clinic_id = t.clinic_id
        where t.product_id = p_product_id
        order by t.at desc
        limit 20
      ) h
    )
  );
$$;

revoke execute on function public.product_detail(uuid) from public, anon;
grant execute on function public.product_detail(uuid) to authenticated, service_role;
