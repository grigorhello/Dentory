-- MS-123 · Adjust, then start (PRD §6.3, f13, f37): what the screen opens with.
-- One active template with its supplies in the template's order, each with the stock it takes from: a countable
-- product's quantity, a multi-use product's unopened and open counts. Archived products are left out, as on the
-- Procedures list. Security invoker, so RLS keeps each clinic to itself; null for a template the caller cannot
-- see, that is archived or that does not exist. Starting the procedure is `stock_procedure_start` (MS-106).
create function public.procedure_template_detail(p_template_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id,
    'name', t.name,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'name', p.name,
        'unit', p.unit,
        'tracking', p.tracking,
        'default_qty', i.default_qty,
        'quantity', s.quantity,
        'unopened', s.unopened,
        'open_count', s.open_count
      ) order by i.position, p.name)
      from public.procedure_template_items i
      join public.products p on p.id = i.product_id and p.archived_at is null
      join public.product_stock s on s.product_id = p.id
      where i.template_id = t.id
    ), '[]'::jsonb)
  )
  from public.procedure_templates t
  where t.id = p_template_id and t.archived_at is null;
$$;
revoke execute on function public.procedure_template_detail(uuid) from public, anon;
grant execute on function public.procedure_template_detail(uuid) to authenticated, service_role;
