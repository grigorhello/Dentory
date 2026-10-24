-- MS-141 follow-up (its review's notes): a receipt copy another delivery of the event is still sending answers "in
-- progress" instead of nothing, so stripe_webhook fails that delivery and Stripe tries again later; a copy whose sender
-- died is sent by that later try once the 10-minute claim is over, instead of being lost.

create or replace function public.billing_receipt_copy(p_stripe_invoice_id text, p_customer_email text)
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
  for update;
  if not found then
    return;
  end if;
  if v_invoice.receipt_copy_claimed_at >= now() - interval '10 minutes' then
    raise exception 'The receipt copy is being sent' using errcode = '55P03';
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
