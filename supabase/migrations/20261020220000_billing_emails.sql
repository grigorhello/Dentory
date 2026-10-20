-- MS-141 · Billing invoices and billing emails (PRD §6.9 and Appendix C billingEmails, f35, MS-100 D18). Invoices are
-- read from billing_invoices (admins only, MS-140). Billing emails: the first is the clinic's primary address, the
-- Stripe customer's, which Stripe sends its receipts to (its API takes one address per customer); it is shown first
-- and is not removable. Every other address gets Dentory's copy of each paid invoice's receipt from stripe_webhook,
-- so invoices and receipts reach every address. An admin may edit the list in read-only mode too: the link to add a
-- card goes to these addresses.

alter table public.billing_invoices add column receipt_copied_at timestamptz;

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

-- Once per paid invoice (stripe_webhook): the clinic, its addresses after the primary and the invoice's figures, for
-- Dentory's copy of the receipt. Nothing when the copy went already, the invoice is not paid, or there is no other
-- address; the invoice is marked either way, so a later address gets the next receipts, not the old ones.
create function public.billing_receipt_copy(p_stripe_invoice_id text)
returns table (
  clinic_name text, emails text[], number text, issued_at timestamptz, amount_cents bigint, currency text,
  hosted_url text, time_zone text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with marked as (
    update public.billing_invoices i
    set receipt_copied_at = now()
    where i.stripe_invoice_id = p_stripe_invoice_id and i.status = 'paid' and i.receipt_copied_at is null
    returning i.clinic_id, i.number, i.issued_at, i.amount_cents, i.currency, i.hosted_url
  )
  select c.name, (engine.billing_emails(c.id))[2:], m.number, m.issued_at, m.amount_cents, m.currency, m.hosted_url,
         c.time_zone
  from marked m
  join public.clinics c on c.id = m.clinic_id
  where coalesce(array_length((engine.billing_emails(c.id))[2:], 1), 0) > 0;
end;
$$;
revoke execute on function public.billing_receipt_copy(text) from public, anon, authenticated;
grant execute on function public.billing_receipt_copy(text) to service_role;
