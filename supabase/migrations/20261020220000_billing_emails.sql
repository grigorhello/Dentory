-- MS-141 · Billing invoices and billing emails (PRD §6.9 and Appendix C billingEmails, f35, MS-100 D18). Invoices are
-- read from billing_invoices (admins only, MS-140); one Stripe tried to charge and could not reads Failed. Billing
-- emails: the first is the address the Stripe customer was created with, which Stripe sends its receipts to (its API
-- takes one address per customer); billing_set_customer keeps it as the list's first, which the app shows first and
-- does not let anyone remove. Every other address gets Dentory's copy of each paid invoice's receipt from
-- stripe_webhook, so invoices and receipts reach every address. An admin may edit the list in read-only mode too: the
-- link to add a card goes to these addresses.

alter table public.billing_invoices
  add column receipt_copied_at timestamptz,
  -- Set while stripe_webhook sends the copies; a claim older than 10 minutes is taken again.
  add column receipt_copy_claimed_at timestamptz,
  -- Stripe tried to charge it and could not; it stays open while Stripe retries.
  add column payment_failed boolean not null default false;

-- The clinic's billing addresses, the primary first: its list, or the first admin's address while the list is empty.
create function engine.billing_emails(p_clinic_id uuid)
returns text[]
language sql
stable
set search_path = ''
as $$
  select case
    when coalesce(array_length(c.billing_emails, 1), 0) > 0 then c.billing_emails
    else array_remove(array[(
      select m.email from public.memberships m
      where m.clinic_id = c.id and m.role = 'admin' and m.status = 'active'
      order by m.invited_at, m.id
      limit 1
    )], null)
  end
  from public.clinics c
  where c.id = p_clinic_id;
$$;

-- The customer billing_checkout just created keeps the address it was created with as the list's first (MS-140's
-- function, which kept the customer only), so the first billing email is always the one Stripe bills.
create or replace function public.billing_set_customer(p_clinic_id uuid, p_customer_id text)
returns text
language sql
security definer
set search_path = ''
as $$
  update public.clinics c
  set stripe_customer_id = coalesce(c.stripe_customer_id, p_customer_id),
      billing_emails = case
        when coalesce(array_length(c.billing_emails, 1), 0) = 0 then coalesce(engine.billing_emails(c.id), '{}')
        else c.billing_emails
      end
  where c.id = p_clinic_id
  returning c.stripe_customer_id;
$$;

-- Clinics that have a Stripe customer but never saved a list keep their current first address the same way.
update public.clinics c
set billing_emails = engine.billing_emails(c.id)
where c.stripe_customer_id is not null
  and coalesce(array_length(c.billing_emails, 1), 0) = 0
  and coalesce(array_length(engine.billing_emails(c.id), 1), 0) > 0;

create function public.billing_emails_list(p_clinic_id uuid)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not coalesce(public.is_admin(p_clinic_id), false) then
    perform engine.fail('42501', 'Only an admin can see billing');
  end if;
  return coalesce(engine.billing_emails(p_clinic_id), '{}');
end;
$$;
revoke execute on function public.billing_emails_list(uuid) from public, anon;
grant execute on function public.billing_emails_list(uuid) to authenticated, service_role;

-- Keeps the primary and saves the addresses after it, trimmed and lowercased, each once: at most 10 in all. A
-- malformed address is refused with itself as the hint, so the sheet can say which.
create function public.billing_emails_save(p_clinic_id uuid, p_extra text[])
returns text[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_primary text;
  v_extra text[] := '{}';
  v_email text;
begin
  if not coalesce(public.is_admin(p_clinic_id), false) then
    perform engine.fail('42501', 'Only an admin can change billing emails');
  end if;
  v_primary := (engine.billing_emails(p_clinic_id))[1];
  if v_primary is null then
    perform engine.fail('22023', 'The clinic has no admin address');
  end if;
  foreach v_email in array coalesce(p_extra, '{}') loop
    v_email := lower(btrim(v_email));
    continue when v_email = '';
    if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
      raise exception 'Enter a valid email' using errcode = '22023', hint = v_email;
    end if;
    if v_email <> lower(v_primary) and not v_email = any(v_extra) then
      v_extra := v_extra || v_email;
    end if;
  end loop;
  if coalesce(array_length(v_extra, 1), 0) > 9 then
    perform engine.fail('22023', 'Up to 10 billing emails');
  end if;
  update public.clinics set billing_emails = array[v_primary] || v_extra where id = p_clinic_id;
  return array[v_primary] || v_extra;
end;
$$;
revoke execute on function public.billing_emails_save(uuid, text[]) from public, anon;
grant execute on function public.billing_emails_save(uuid, text[]) to authenticated, service_role;

-- Once per paid invoice (stripe_webhook): claims Dentory's copy of its receipt and answers the clinic, the addresses
-- the copy goes to and the invoice's figures. The copy goes to every billing email but the one Stripe sent its own
-- receipt to (the invoice's customer email, else the list's first). The claim holds 10 minutes: billing_receipt_finish
-- marks the copy sent, or releases it when the send failed, so Stripe's retry of the event sends it again. Nothing when
-- the copy went already or is being sent, or the invoice is not paid; an invoice with no other address is marked at
-- once, so an address added later gets the next receipts, not the old ones.
create function public.billing_receipt_copy(p_stripe_invoice_id text, p_customer_email text)
returns table (
  clinic_name text, emails text[], number text, issued_at timestamptz, amount_cents bigint, currency text,
  hosted_url text, time_zone text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invoice public.billing_invoices;
  v_stripe_email text := lower(nullif(btrim(p_customer_email), ''));
  v_emails text[];
begin
  select * into v_invoice
  from public.billing_invoices i
  where i.stripe_invoice_id = p_stripe_invoice_id and i.status = 'paid' and i.receipt_copied_at is null
    and (i.receipt_copy_claimed_at is null or i.receipt_copy_claimed_at < now() - interval '10 minutes')
  for update;
  if not found then
    return;
  end if;
  v_emails := array(
    select x.email
    from unnest(engine.billing_emails(v_invoice.clinic_id)) with ordinality as x (email, n)
    where case when v_stripe_email is null then x.n > 1 else lower(x.email) <> v_stripe_email end
    order by x.n
  );
  if coalesce(array_length(v_emails, 1), 0) = 0 then
    update public.billing_invoices set receipt_copied_at = now() where id = v_invoice.id;
    return;
  end if;
  update public.billing_invoices set receipt_copy_claimed_at = now() where id = v_invoice.id;
  return query
  select c.name, v_emails, v_invoice.number, v_invoice.issued_at, v_invoice.amount_cents, v_invoice.currency,
         v_invoice.hosted_url, c.time_zone
  from public.clinics c
  where c.id = v_invoice.clinic_id;
end;
$$;
revoke execute on function public.billing_receipt_copy(text, text) from public, anon, authenticated;
grant execute on function public.billing_receipt_copy(text, text) to service_role;

-- What became of the copies billing_receipt_copy handed out: sent marks the invoice for good; not sent frees it for
-- Stripe's retry of the event.
create function public.billing_receipt_finish(p_stripe_invoice_id text, p_sent boolean)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.billing_invoices
  set receipt_copied_at = case when p_sent then now() end, receipt_copy_claimed_at = null
  where stripe_invoice_id = p_stripe_invoice_id and receipt_copied_at is null;
$$;
revoke execute on function public.billing_receipt_finish(text, boolean) from public, anon, authenticated;
grant execute on function public.billing_receipt_finish(text, boolean) to service_role;

-- An open invoice Stripe tried to charge and could not (stripe_webhook): Invoices shows it as Failed until it is paid.
create function public.billing_invoice_payment_failed(p_stripe_invoice_id text)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.billing_invoices set payment_failed = true, updated_at = now()
  where stripe_invoice_id = p_stripe_invoice_id;
$$;
revoke execute on function public.billing_invoice_payment_failed(text) from public, anon, authenticated;
grant execute on function public.billing_invoice_payment_failed(text) to service_role;
