-- MS-142 · Read-only mode (PRD §9, MS-100 G5). The write RPCs already refuse a read-only clinic with "The clinic is
-- read-only until a payment method is added" (42501), which the app shows as read-only mode. The tables members write
-- directly refused it through their policies instead: an insert or an update as a row-level security error, which the
-- app read as a missing permission, and a delete as nothing at all, the row simply not seen. A trigger now refuses
-- those writes with the same sentence, and the delete policies no longer hide a read-only clinic's rows, so the
-- trigger sees them. Writes the server makes itself (the RPCs, the billing webhook, the Edge Functions) do not run as
-- `authenticated` and pass. Reading, a member's "seen" marker and a device's push token stay open.

create function engine.refuse_read_only()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_row jsonb := to_jsonb(case when tg_op = 'DELETE' then old else new end);
  v_clinic_id uuid := (v_row ->> tg_argv[0])::uuid;
begin
  if current_user = 'authenticated' and v_clinic_id is not null and not public.clinic_can_write(v_clinic_id) then
    raise exception 'The clinic is read-only until a payment method is added' using errcode = '42501';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger clinics_refuse_read_only before update on public.clinics
  for each row execute function engine.refuse_read_only('id');
create trigger memberships_refuse_read_only before insert or update or delete on public.memberships
  for each row execute function engine.refuse_read_only('clinic_id');
create trigger categories_refuse_read_only before insert or update or delete on public.categories
  for each row execute function engine.refuse_read_only('clinic_id');
create trigger products_refuse_read_only before insert or update on public.products
  for each row execute function engine.refuse_read_only('clinic_id');
create trigger procedure_templates_refuse_read_only before insert or update or delete on public.procedure_templates
  for each row execute function engine.refuse_read_only('clinic_id');
create trigger procedure_template_items_refuse_read_only
  before insert or update or delete on public.procedure_template_items
  for each row execute function engine.refuse_read_only('clinic_id');
create trigger invoices_refuse_read_only before insert or update on public.invoices
  for each row execute function engine.refuse_read_only('clinic_id');
create trigger invoice_lines_refuse_read_only before insert or update on public.invoice_lines
  for each row execute function engine.refuse_read_only('clinic_id');
create trigger supplier_aliases_refuse_read_only before insert or update or delete on public.supplier_aliases
  for each row execute function engine.refuse_read_only('clinic_id');
create trigger to_buy_items_refuse_read_only before insert or update or delete on public.to_buy_items
  for each row execute function engine.refuse_read_only('clinic_id');

-- The delete policies keep their role checks; the trigger above says read-only instead of deleting nothing.
drop policy memberships_admin_delete on public.memberships;
create policy memberships_admin_delete on public.memberships for delete to authenticated
  using (public.is_admin(clinic_id));
drop policy categories_admin_delete on public.categories;
create policy categories_admin_delete on public.categories for delete to authenticated
  using (public.is_admin(clinic_id));
drop policy procedure_templates_admin_delete on public.procedure_templates;
create policy procedure_templates_admin_delete on public.procedure_templates for delete to authenticated
  using (public.is_admin(clinic_id));
drop policy procedure_template_items_admin_delete on public.procedure_template_items;
create policy procedure_template_items_admin_delete on public.procedure_template_items for delete to authenticated
  using (public.is_admin(clinic_id));
drop policy to_buy_items_member_delete on public.to_buy_items;
create policy to_buy_items_member_delete on public.to_buy_items for delete to authenticated
  using (public.is_member(clinic_id) and (status = 'to_buy' or public.is_admin(clinic_id)));
