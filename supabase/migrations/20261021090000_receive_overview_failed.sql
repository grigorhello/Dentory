-- MS-129 fix (Refs #100, decided in the build thread on 2026-10-26) · A failed reading shows in Continue reviewing.
-- A reading that failed after the admin had left Review invoice told nobody: receive_overview listed only the invoices
-- being read or ready to review, and only a reading that ends ready raises an alert. Receive delivery's Continue
-- reviewing now lists the invoices whose reading failed too, each with the time it failed (`failed_at`, the invoice's
-- read_at, which invoice_reading_fail and the each-minute timeout set), so the app shows "Couldn't read · 9:41 AM" and
-- opens the failure screen with Try again and Receive manually; both set the invoice aside, so it is listed no more.
-- Confirmed and discarded invoices stay out. No alert kind and no push are added. Everything else is as MS-126 made
-- it: admins only, newest upload first, the To buy lines marked Ordered, and a read for a read-only clinic too.
create or replace function public.receive_overview(p_clinic_id uuid)
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
          'id', i.id, 'status', i.status, 'supplier', i.supplier, 'created_at', i.created_at,
          'failed_at', case when i.status = 'failed' then coalesce(i.read_at, i.created_at) end
        ) order by i.created_at desc, i.id)
      from public.invoices i
      where i.clinic_id = p_clinic_id and i.status in ('reading', 'ready', 'failed')
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
