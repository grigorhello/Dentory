-- MS-115 · The Inventory list in one query (PRD §6.4): every active product of the clinic with its category,
-- its stock figures and its status from product_status. Security invoker, so the policies on products,
-- categories and the stock tables decide what the caller sees: a member gets their clinic, anyone else nothing.
create function public.inventory_list(p_clinic_id uuid)
returns table (
  product_id uuid,
  name text,
  category_name text,
  unit text,
  tracking text,
  location text,
  quantity numeric,
  unopened numeric,
  open_count integer,
  minimum numeric,
  status text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    p.id,
    p.name,
    c.name,
    p.unit,
    p.tracking::text,
    p.location,
    s.quantity,
    s.unopened,
    s.open_count,
    p.minimum,
    s.status
  from public.products p
  join public.product_status s on s.product_id = p.id
  left join public.categories c on c.id = p.category_id
  where p.clinic_id = p_clinic_id and p.archived_at is null
  order by p.name;
$$;

revoke execute on function public.inventory_list(uuid) from public, anon;
grant execute on function public.inventory_list(uuid) to authenticated, service_role;
