-- MS-105 · Clinic isolation and Admin/Staff permissions (PRD §2 role table, §9 privacy; MS-100 G5).
-- Every policy starts from active membership. Writes also need the clinic to be writable (trial still
-- running or paid). Stock tables (batches, open_items, transactions) and procedure events take no direct
-- writes from the app at all: the MS-106 RPC functions are the only way in. Update policies let a member
-- see the row and fail the role check in WITH CHECK, so Staff gets a clear error instead of a silent no-op.

-- Helpers ------------------------------------------------------------------------------------------

-- Clinics the caller is an active member of. SECURITY DEFINER so policies on memberships do not recurse.
create function public.current_clinic_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.clinic_id
  from public.memberships m
  where m.user_id = auth.uid() and m.status = 'active';
$$;

-- 'admin', 'staff', or null when the caller is not an active member of the clinic.
create function public.current_role_in(p_clinic_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select m.role::text
  from public.memberships m
  where m.clinic_id = p_clinic_id and m.user_id = auth.uid() and m.status = 'active'
  limit 1;
$$;

create function public.is_member(p_clinic_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_role_in(p_clinic_id) is not null;
$$;

create function public.is_admin(p_clinic_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_role_in(p_clinic_id) = 'admin';
$$;

-- False once the trial ended without a payment method, or the subscription is read-only or canceled
-- (MS-100 G5): the app keeps reading and every write is refused.
create function public.clinic_can_write(p_clinic_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.clinics c
    where c.id = p_clinic_id
      and (
        c.subscription_status in ('active', 'past_due')
        or (c.subscription_status = 'trialing' and c.trial_ends_at > now())
      )
  );
$$;

revoke execute on function public.current_clinic_ids(), public.current_role_in(uuid), public.is_member(uuid),
  public.is_admin(uuid), public.clinic_can_write(uuid) from public, anon;
grant execute on function public.current_clinic_ids(), public.current_role_in(uuid), public.is_member(uuid),
  public.is_admin(uuid), public.clinic_can_write(uuid) to authenticated, service_role;

-- A clinic always keeps at least one active Admin.
create function public.memberships_keep_an_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.role = 'admin' and old.status = 'active'
     and (tg_op = 'DELETE' or new.role <> 'admin' or new.status <> 'active')
     and not exists (
       select 1 from public.memberships m
       where m.clinic_id = old.clinic_id and m.role = 'admin' and m.status = 'active' and m.id <> old.id
     )
  then
    raise exception 'a clinic needs at least one active admin'
      using errcode = 'restrict_violation';
  end if;
  return coalesce(new, old);
end;
$$;

create trigger memberships_keep_an_admin
  before update or delete on public.memberships
  for each row execute function public.memberships_keep_an_admin();

-- Grants ------------------------------------------------------------------------------------------
-- The image's default ACL gives the API roles nothing on new tables, so every right is explicit here.
-- service_role (Edge Functions, cron) bypasses RLS and gets everything the ledger rules allow.

grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on all tables in schema public to service_role;
revoke update, delete, truncate on public.transactions from service_role;
revoke delete, truncate on public.products from service_role;
grant select on public.product_stock to service_role;

-- Members read these; the policies narrow them to their clinics.
grant select on public.clinics, public.profiles, public.memberships, public.categories, public.products,
  public.batches, public.open_items, public.procedure_templates, public.procedure_template_items,
  public.procedure_events, public.procedure_event_items, public.procedure_event_openings,
  public.invoices, public.invoice_lines, public.to_buy_items, public.transactions, public.alerts,
  public.alert_reads, public.push_tokens, public.export_jobs, public.product_stock
  to authenticated;

-- Direct writes, each narrowed by role in its policy. No INSERT, UPDATE or DELETE on batches,
-- open_items, transactions or the procedure event tables: those go through the MS-106 RPCs.
grant update on public.clinics to authenticated;
grant insert, update on public.profiles to authenticated;
grant insert, update, delete on public.memberships to authenticated;
grant insert, update, delete on public.categories to authenticated;
grant insert, update on public.products to authenticated;
grant insert, update, delete on public.procedure_templates, public.procedure_template_items to authenticated;
grant insert, update on public.invoices, public.invoice_lines to authenticated;
grant select, insert, update, delete on public.supplier_aliases to authenticated;
grant insert, update, delete on public.to_buy_items to authenticated;
grant insert, update, delete on public.alert_reads to authenticated;
grant insert, update, delete on public.push_tokens to authenticated;
grant insert on public.export_jobs to authenticated;

-- Policies ----------------------------------------------------------------------------------------

create policy clinics_read on public.clinics for select to authenticated
  using (public.is_member(id));
create policy clinics_admin_update on public.clinics for update to authenticated
  using (public.is_member(id))
  with check (public.is_admin(id) and public.clinic_can_write(id));

-- Own profile, plus the people who share a clinic (names in history and the team list).
create policy profiles_read on public.profiles for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.memberships m
      where m.user_id = profiles.user_id and m.status = 'active'
        and m.clinic_id in (select public.current_clinic_ids())
    )
  );
create policy profiles_own_insert on public.profiles for insert to authenticated
  with check (user_id = auth.uid());
create policy profiles_own_update on public.profiles for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- The team: everyone reads it, only admins invite, change roles or revoke.
create policy memberships_read on public.memberships for select to authenticated
  using (public.is_member(clinic_id));
create policy memberships_admin_insert on public.memberships for insert to authenticated
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy memberships_admin_update on public.memberships for update to authenticated
  using (public.is_member(clinic_id))
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy memberships_admin_delete on public.memberships for delete to authenticated
  using (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));

create policy categories_read on public.categories for select to authenticated
  using (public.is_member(clinic_id));
create policy categories_admin_insert on public.categories for insert to authenticated
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy categories_admin_update on public.categories for update to authenticated
  using (public.is_member(clinic_id))
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy categories_admin_delete on public.categories for delete to authenticated
  using (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));

-- Products: everyone reads, admins create, edit and archive.
create policy products_read on public.products for select to authenticated
  using (public.is_member(clinic_id));
create policy products_admin_insert on public.products for insert to authenticated
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy products_admin_update on public.products for update to authenticated
  using (public.is_member(clinic_id))
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));

-- Stock and procedure history: read by members, written only by the MS-106 functions.
create policy batches_read on public.batches for select to authenticated
  using (public.is_member(clinic_id));
create policy open_items_read on public.open_items for select to authenticated
  using (public.is_member(clinic_id));
create policy transactions_read on public.transactions for select to authenticated
  using (public.is_member(clinic_id));
create policy procedure_events_read on public.procedure_events for select to authenticated
  using (public.is_member(clinic_id));
create policy procedure_event_items_read on public.procedure_event_items for select to authenticated
  using (public.is_member(clinic_id));
create policy procedure_event_openings_read on public.procedure_event_openings for select to authenticated
  using (public.is_member(clinic_id));

-- Templates: admin-only to change.
create policy procedure_templates_read on public.procedure_templates for select to authenticated
  using (public.is_member(clinic_id));
create policy procedure_templates_admin_insert on public.procedure_templates for insert to authenticated
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy procedure_templates_admin_update on public.procedure_templates for update to authenticated
  using (public.is_member(clinic_id))
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy procedure_templates_admin_delete on public.procedure_templates for delete to authenticated
  using (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy procedure_template_items_read on public.procedure_template_items for select to authenticated
  using (public.is_member(clinic_id));
create policy procedure_template_items_admin_insert on public.procedure_template_items for insert to authenticated
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy procedure_template_items_admin_update on public.procedure_template_items for update to authenticated
  using (public.is_member(clinic_id))
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy procedure_template_items_admin_delete on public.procedure_template_items for delete to authenticated
  using (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));

-- Receiving is admin-only, reading invoices included.
create policy invoices_admin_read on public.invoices for select to authenticated
  using (public.is_admin(clinic_id));
create policy invoices_admin_insert on public.invoices for insert to authenticated
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy invoices_admin_update on public.invoices for update to authenticated
  using (public.is_admin(clinic_id))
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy invoice_lines_admin_read on public.invoice_lines for select to authenticated
  using (public.is_admin(clinic_id));
create policy invoice_lines_admin_insert on public.invoice_lines for insert to authenticated
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy invoice_lines_admin_update on public.invoice_lines for update to authenticated
  using (public.is_admin(clinic_id))
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));
create policy supplier_aliases_admin_all on public.supplier_aliases for all to authenticated
  using (public.is_admin(clinic_id))
  with check (public.is_admin(clinic_id) and public.clinic_can_write(clinic_id));

-- To buy: everyone adds and changes quantities; only admins move an item past "to buy".
create policy to_buy_items_read on public.to_buy_items for select to authenticated
  using (public.is_member(clinic_id));
create policy to_buy_items_member_insert on public.to_buy_items for insert to authenticated
  with check (
    public.is_member(clinic_id) and public.clinic_can_write(clinic_id)
    and (status = 'to_buy' or public.is_admin(clinic_id))
  );
create policy to_buy_items_member_update on public.to_buy_items for update to authenticated
  using (public.is_member(clinic_id))
  with check (
    public.is_member(clinic_id) and public.clinic_can_write(clinic_id)
    and (status = 'to_buy' or public.is_admin(clinic_id))
  );
create policy to_buy_items_member_delete on public.to_buy_items for delete to authenticated
  using (public.is_member(clinic_id) and public.clinic_can_write(clinic_id) and (status = 'to_buy' or public.is_admin(clinic_id)));

-- Alerts are written by the engine; members read them and keep their own "seen" marker.
create policy alerts_read on public.alerts for select to authenticated
  using (public.is_member(clinic_id));
create policy alert_reads_own_all on public.alert_reads for all to authenticated
  using (user_id = auth.uid() and public.is_member(clinic_id))
  with check (user_id = auth.uid() and public.is_member(clinic_id));

create policy push_tokens_own_all on public.push_tokens for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy export_jobs_admin_read on public.export_jobs for select to authenticated
  using (public.is_admin(clinic_id));
create policy export_jobs_admin_insert on public.export_jobs for insert to authenticated
  with check (public.is_admin(clinic_id) and requested_by = auth.uid());

-- Storage -----------------------------------------------------------------------------------------
-- Objects live under "<clinic_id>/...". Invoices are admin-only; logos are read by members.

insert into storage.buckets (id, name, public)
values ('invoices', 'invoices', false), ('logos', 'logos', false)
on conflict (id) do nothing;

create policy invoices_admin_objects on storage.objects for all to authenticated
  using (bucket_id = 'invoices' and public.is_admin((storage.foldername(name))[1]::uuid))
  with check (bucket_id = 'invoices' and public.is_admin((storage.foldername(name))[1]::uuid));

create policy logos_member_read on storage.objects for select to authenticated
  using (bucket_id = 'logos' and public.is_member((storage.foldername(name))[1]::uuid));
create policy logos_admin_write on storage.objects for insert to authenticated
  with check (bucket_id = 'logos' and public.is_admin((storage.foldername(name))[1]::uuid));
create policy logos_admin_update on storage.objects for update to authenticated
  using (bucket_id = 'logos' and public.is_admin((storage.foldername(name))[1]::uuid))
  with check (bucket_id = 'logos' and public.is_admin((storage.foldername(name))[1]::uuid));
create policy logos_admin_delete on storage.objects for delete to authenticated
  using (bucket_id = 'logos' and public.is_admin((storage.foldername(name))[1]::uuid));
