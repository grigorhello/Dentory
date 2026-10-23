-- MS-126 · Receive delivery: choose how (PRD §6.5, Appendix B `receive`; f22). What the screen lists under its three
-- options, for an admin only: receiving is admin-only (PRD §2), so a member who is not an admin of the clinic is
-- refused here as well as given no way to the screen.
-- - invoices: the clinic's invoices still being read or ready to review ("Continue reviewing"), newest first;
-- - waiting: the To buy lines marked Ordered ("Waiting for delivery"), for reference only, in the To buy tab's
--   Ordered order (newest order first, then by name), with the product's name, unit and supplier.
-- Security invoker, so RLS keeps each clinic to itself; a read, so a read-only clinic may call it too.
create function public.receive_overview(p_clinic_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if not coalesce(public.is_admin(p_clinic_id), false) then
    raise exception 'Only an admin can receive deliveries' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'invoices', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', i.id, 'status', i.status, 'supplier', i.supplier, 'created_at', i.created_at
        ) order by i.created_at desc, i.id)
      from public.invoices i
      where i.clinic_id = p_clinic_id and i.status in ('reading', 'ready')
    ), '[]'::jsonb),
    'waiting', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', t.id, 'product_id', p.id, 'name', p.name, 'unit', p.unit, 'supplier', p.supplier, 'qty', t.qty,
          'ordered_at', t.ordered_at
        ) order by t.ordered_at desc, lower(p.name), t.id)
      from public.to_buy_items t
      join public.products p on p.id = t.product_id
      where t.clinic_id = p_clinic_id and t.status = 'ordered' and p.archived_at is null
    ), '[]'::jsonb)
  );
end;
$$;
revoke execute on function public.receive_overview(uuid) from public, anon;
grant execute on function public.receive_overview(uuid) to authenticated, service_role;
