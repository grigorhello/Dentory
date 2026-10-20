-- MS-140 · Billing (PRD §6.9 and §9 Billing, f34, MS-100 D11). Three months free from clinic creation
-- (clinics.trial_ends_at), then $99 per clinic per month, or $49.50 for a clinic Dentory grants the lifetime 50%
-- promotion (clinics.promo_lifetime_50, set by hand, never by the app). Stripe holds the subscription: the admin adds
-- a card on Stripe Checkout and changes it on the Customer Portal, both opened through the billing_checkout and
-- billing_portal Edge Functions, and stripe_webhook writes back what Stripe reports through the service-role functions
-- below. clinic_can_write (MS-105) reads the status they keep.

-- What Stripe reports beyond the status: the card on file and the next payment. Admins read it.
create table public.clinic_billing (
  clinic_id uuid primary key references public.clinics (id) on delete cascade,
  card_brand text,
  card_last4 text check (card_last4 ~ '^[0-9]{4}$'),
  current_period_end timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.clinic_billing enable row level security;
create policy clinic_billing_admin_read on public.clinic_billing for select to authenticated
  using (public.is_admin(clinic_id));
grant select on public.clinic_billing to authenticated;

-- Stripe's invoices for the clinic's subscription, listed by MS-141. Admins read them.
create table public.billing_invoices (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  stripe_invoice_id text not null unique,
  number text,
  issued_at timestamptz not null,
  amount_cents bigint not null,
  currency text not null,
  status text not null,
  hosted_url text,
  pdf_url text,
  updated_at timestamptz not null default now()
);
create index billing_invoices_clinic_idx on public.billing_invoices (clinic_id, issued_at desc);
alter table public.billing_invoices enable row level security;
create policy billing_invoices_admin_read on public.billing_invoices for select to authenticated
  using (public.is_admin(clinic_id));
grant select on public.billing_invoices to authenticated;

-- Billing as the admin sees it (f34): the trial, the plan, the card, how many invoices, and the first billing
-- email (the clinic's own list, or the first admin's address while the list is empty).
create function public.billing_summary(p_clinic_id uuid)
returns table (
  trial_ends_at timestamptz,
  subscription_status public.subscription_status,
  has_subscription boolean,
  promo_lifetime_50 boolean,
  card_brand text,
  card_last4 text,
  current_period_end timestamptz,
  invoice_count integer,
  billing_email text,
  billing_email_count integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not coalesce(public.is_admin(p_clinic_id), false) then
    perform engine.fail('42501', 'Only an admin can see billing');
  end if;
  return query
  select c.trial_ends_at, c.subscription_status, c.stripe_subscription_id is not null, c.promo_lifetime_50,
         b.card_brand, b.card_last4, b.current_period_end,
         (select count(*)::integer from public.billing_invoices i where i.clinic_id = c.id),
         coalesce(c.billing_emails[1], a.email),
         case
           when coalesce(array_length(c.billing_emails, 1), 0) > 0 then array_length(c.billing_emails, 1)
           when a.email is not null then 1
           else 0
         end
  from public.clinics c
  left join public.clinic_billing b on b.clinic_id = c.id
  left join lateral (
    select m.email from public.memberships m
    where m.clinic_id = c.id and m.role = 'admin' and m.status = 'active'
    order by m.invited_at, m.id
    limit 1
  ) a on true
  where c.id = p_clinic_id;
end;
$$;
revoke execute on function public.billing_summary(uuid) from public, anon;
grant execute on function public.billing_summary(uuid) to authenticated, service_role;

-- billing_checkout and billing_portal, for the admin p_user_id: the clinic, its Stripe customer and subscription (null
-- the first time), the trial, the promotion and the address Stripe bills. Anyone else is refused.
create function public.billing_account(p_clinic_id uuid, p_user_id uuid)
returns table (
  clinic_name text,
  stripe_customer_id text,
  stripe_subscription_id text,
  trial_ends_at timestamptz,
  promo_lifetime_50 boolean,
  billing_email text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_user_id is null or not exists (
    select 1 from public.memberships m
    where m.clinic_id = p_clinic_id and m.user_id = p_user_id and m.role = 'admin' and m.status = 'active'
  ) then
    perform engine.fail('42501', 'Only an admin can manage billing');
  end if;
  return query
  select c.name, c.stripe_customer_id, c.stripe_subscription_id, c.trial_ends_at, c.promo_lifetime_50,
         coalesce(c.billing_emails[1], (select u.email::text from auth.users u where u.id = p_user_id))
  from public.clinics c
  where c.id = p_clinic_id;
end;
$$;
revoke execute on function public.billing_account(uuid, uuid) from public, anon, authenticated;
grant execute on function public.billing_account(uuid, uuid) to service_role;

-- Keeps the Stripe customer billing_checkout just created; when another request kept one first, answers that one.
create function public.billing_set_customer(p_clinic_id uuid, p_customer_id text)
returns text
language sql
security definer
set search_path = ''
as $$
  update public.clinics set stripe_customer_id = coalesce(stripe_customer_id, p_customer_id)
  where id = p_clinic_id
  returning stripe_customer_id;
$$;
revoke execute on function public.billing_set_customer(uuid, text) from public, anon, authenticated;
grant execute on function public.billing_set_customer(uuid, text) to service_role;

-- A subscription as Stripe reports it (webhook). A card on file keeps the clinic writable through and after the trial:
-- trialing and active are active; past_due stays past_due while Stripe retries; unpaid and paused are read-only. A
-- subscription that ends leaves the clinic trialing while its free months last, canceled after, and lets the admin
-- start a new one. Answers the clinic, or null for a customer Dentory does not know.
create function public.billing_apply_subscription(
  p_customer_id text,
  p_subscription_id text,
  p_status text,
  p_period_end timestamptz,
  p_clinic_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_clinic public.clinics;
begin
  select * into v_clinic from public.clinics c
  where c.stripe_customer_id = p_customer_id or (p_clinic_id is not null and c.id = p_clinic_id)
  order by (c.stripe_customer_id = p_customer_id) desc nulls last
  limit 1
  for update;
  if v_clinic.id is null then
    return null;
  end if;

  if p_status in ('canceled', 'incomplete_expired') then
    -- Only the clinic's current subscription can end it; a late event about an older one changes nothing.
    if v_clinic.stripe_subscription_id is distinct from p_subscription_id then
      return v_clinic.id;
    end if;
    update public.clinics
    set stripe_subscription_id = null,
        subscription_status =
          (case when trial_ends_at > now() then 'trialing' else 'canceled' end)::public.subscription_status
    where id = v_clinic.id;
    update public.clinic_billing set current_period_end = null, updated_at = now() where clinic_id = v_clinic.id;
    return v_clinic.id;
  end if;

  update public.clinics
  set stripe_customer_id = coalesce(stripe_customer_id, p_customer_id),
      stripe_subscription_id = p_subscription_id,
      subscription_status = case p_status
        when 'trialing' then 'active'
        when 'active' then 'active'
        when 'past_due' then 'past_due'
        when 'unpaid' then 'read_only'
        when 'paused' then 'read_only'
        else subscription_status
      end::public.subscription_status
  where id = v_clinic.id;
  insert into public.clinic_billing (clinic_id, current_period_end)
  values (v_clinic.id, p_period_end)
  on conflict (clinic_id) do update set current_period_end = excluded.current_period_end, updated_at = now();
  return v_clinic.id;
end;
$$;
revoke execute on function public.billing_apply_subscription(text, text, text, timestamptz, uuid)
  from public, anon, authenticated;
grant execute on function public.billing_apply_subscription(text, text, text, timestamptz, uuid) to service_role;

-- The card Stripe charges for the customer (webhook): its brand and last four digits, nothing else.
create function public.billing_apply_card(p_customer_id text, p_brand text, p_last4 text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_clinic_id uuid;
begin
  select c.id into v_clinic_id from public.clinics c where c.stripe_customer_id = p_customer_id;
  if v_clinic_id is null then
    return null;
  end if;
  insert into public.clinic_billing (clinic_id, card_brand, card_last4)
  values (v_clinic_id, nullif(p_brand, ''), nullif(p_last4, ''))
  on conflict (clinic_id) do update
    set card_brand = excluded.card_brand, card_last4 = excluded.card_last4, updated_at = now();
  return v_clinic_id;
end;
$$;
revoke execute on function public.billing_apply_card(text, text, text) from public, anon, authenticated;
grant execute on function public.billing_apply_card(text, text, text) to service_role;

-- One of the customer's invoices as Stripe reports it (webhook): created or brought up to date.
create function public.billing_record_invoice(
  p_customer_id text,
  p_stripe_invoice_id text,
  p_number text,
  p_issued_at timestamptz,
  p_amount_cents bigint,
  p_currency text,
  p_status text,
  p_hosted_url text,
  p_pdf_url text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_clinic_id uuid;
begin
  select c.id into v_clinic_id from public.clinics c where c.stripe_customer_id = p_customer_id;
  if v_clinic_id is null then
    return null;
  end if;
  insert into public.billing_invoices
    (clinic_id, stripe_invoice_id, number, issued_at, amount_cents, currency, status, hosted_url, pdf_url)
  values
    (v_clinic_id, p_stripe_invoice_id, p_number, p_issued_at, p_amount_cents, lower(p_currency), p_status, p_hosted_url,
     p_pdf_url)
  on conflict (stripe_invoice_id) do update
    set number = excluded.number, amount_cents = excluded.amount_cents, currency = excluded.currency,
        status = excluded.status, hosted_url = excluded.hosted_url, pdf_url = excluded.pdf_url, updated_at = now();
  return v_clinic_id;
end;
$$;
revoke execute on function public.billing_record_invoice(text, text, text, timestamptz, bigint, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.billing_record_invoice(text, text, text, timestamptz, bigint, text, text, text, text)
  to service_role;
