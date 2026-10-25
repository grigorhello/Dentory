-- MS-127 · Receive manually (PRD §6.5, Appendix B `manual`, Appendix C `pickProduct`; f24). Choose product lists the
-- clinic's active products with what the form needs to turn a delivery into stock: the unit each is counted in, the
-- pack it is received in and that pack's size, how it is tracked, and its stock (unopened and open for a multi-use
-- product, whose received units are unopened ones). The receipt itself is MS-106's stock_receive, with one line in
-- counted units and the cost per counted unit, ref_type 'manual'.
-- Admin only, as receiving is (PRD §2): a member who is not an admin of the clinic is refused here as well as given no
-- way to the screen. Security invoker, so RLS keeps each clinic to itself; a read, so a read-only clinic's admin may
-- call it too (stock_receive refuses the receipt itself, MS-142).
create function public.receive_products(p_clinic_id uuid)
returns table (
  id uuid,
  name text,
  category_name text,
  unit text,
  pack_unit text,
  pack_size integer,
  tracking text,
  quantity numeric,
  unopened numeric,
  open_count integer
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if not coalesce(public.is_admin(p_clinic_id), false) then
    raise exception 'Only an admin can receive deliveries' using errcode = '42501';
  end if;
  return query
    select p.id, p.name, c.name, p.unit, p.pack_unit, p.pack_size, p.tracking::text, s.quantity, s.unopened,
      s.open_count
    from public.products p
    join public.product_stock s on s.product_id = p.id
    left join public.categories c on c.id = p.category_id
    where p.clinic_id = p_clinic_id and p.archived_at is null
    order by lower(p.name), p.id;
end;
$$;
revoke execute on function public.receive_products(uuid) from public, anon;
grant execute on function public.receive_products(uuid) to authenticated, service_role;
