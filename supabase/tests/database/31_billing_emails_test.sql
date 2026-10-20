-- MS-141 · Billing emails and invoices: who may read and change the addresses, how they are kept, that a read-only
-- clinic may still change them, and the receipt copy the webhook sends once per paid invoice.
begin;
select plan(17);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000020401', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000020402', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000020403', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'solo@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, trial_ends_at, stripe_customer_id) values
  ('00000000-0000-4000-8000-000000020411', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', now() - interval '1 day', 'cus_smile'),
  ('00000000-0000-4000-8000-000000020412', 'Solo Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '60 days', 'cus_solo');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status, invited_at) values
  ('00000000-0000-4000-8000-000000020411', '00000000-0000-4000-8000-000000020401', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active', now() - interval '10 days'),
  ('00000000-0000-4000-8000-000000020411', '00000000-0000-4000-8000-000000020402', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active', now() - interval '5 days'),
  ('00000000-0000-4000-8000-000000020412', '00000000-0000-4000-8000-000000020403', 'solo@dentory.test', 'Solo Admin', 'admin', 'active', now() - interval '30 days');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create function pg_temp.hint_of(p_sql text) returns text language plpgsql as $$
declare
  v_hint text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint;
  return v_hint;
end;
$$;

select ok(not has_function_privilege('authenticated', 'public.billing_receipt_copy(text)', 'execute'),
  'members cannot claim a receipt copy');

-- Who may read and change them.
select pg_temp.act_as('00000000-0000-4000-8000-000000020402');
select throws_ok($$select public.billing_emails_list('00000000-0000-4000-8000-000000020411')$$, '42501',
  'Only an admin can see billing', 'Staff cannot read them');
select throws_ok($$select public.billing_emails_save('00000000-0000-4000-8000-000000020411', array['a@b.co'])$$,
  '42501', 'Only an admin can change billing emails', 'nor change them');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000020403');
select throws_ok($$select public.billing_emails_list('00000000-0000-4000-8000-000000020411')$$, '42501',
  'Only an admin can see billing', 'another clinic''s admin cannot either');
reset role;

-- The admin's list: the first admin's address until the clinic has its own, then what was saved.
select pg_temp.act_as('00000000-0000-4000-8000-000000020401');
select is(public.billing_emails_list('00000000-0000-4000-8000-000000020411'), array['sarah@dentory.test'],
  'the first admin''s address comes first');
select is(
  public.billing_emails_save('00000000-0000-4000-8000-000000020411',
    array[' Books@Smile.ca ', 'books@smile.ca', '', 'SARAH@dentory.test', 'owner@smile.ca']),
  array['sarah@dentory.test', 'books@smile.ca', 'owner@smile.ca'],
  'trimmed, lowercased, each once, the primary kept first, in a read-only clinic too'
);
select is(public.billing_emails_list('00000000-0000-4000-8000-000000020411'),
  array['sarah@dentory.test', 'books@smile.ca', 'owner@smile.ca'], 'and read back');
select throws_ok($$select public.billing_emails_save('00000000-0000-4000-8000-000000020411', array['books@smile'])$$,
  '22023', 'Enter a valid email', 'a malformed address is refused');
select is(pg_temp.hint_of($$select public.billing_emails_save('00000000-0000-4000-8000-000000020411', array['books@smile'])$$),
  'books@smile', 'naming the address');
select throws_ok(
  $$select public.billing_emails_save('00000000-0000-4000-8000-000000020411',
    array(select 'a' || n || '@smile.ca' from generate_series(1, 10) n))$$,
  '22023', 'Up to 10 billing emails', 'ten addresses at most');
select is(public.billing_emails_save('00000000-0000-4000-8000-000000020411', array[]::text[]), array['sarah@dentory.test'],
  'removing every other address leaves the primary');
select is((select summary.billing_email_count from public.billing_summary('00000000-0000-4000-8000-000000020411') summary), 1,
  'Billing''s row counts them');
select public.billing_emails_save('00000000-0000-4000-8000-000000020411', array['books@smile.ca']);
reset role;

-- The receipt copy, once per paid invoice, to the addresses after the primary.
insert into public.billing_invoices (clinic_id, stripe_invoice_id, number, issued_at, amount_cents, currency, status, hosted_url) values
  ('00000000-0000-4000-8000-000000020411', 'in_paid', 'DEN-0001', '2027-01-06 14:00+00', 4950, 'usd', 'paid', 'https://invoice.stripe.com/i/1'),
  ('00000000-0000-4000-8000-000000020411', 'in_open', 'DEN-0002', '2027-02-06 14:00+00', 4950, 'usd', 'open', null),
  ('00000000-0000-4000-8000-000000020412', 'in_solo', 'DEN-0003', '2027-01-06 14:00+00', 9900, 'usd', 'paid', null);
select results_eq(
  $$select clinic_name, emails, number, amount_cents, currency, time_zone from public.billing_receipt_copy('in_paid')$$,
  $$values ('Smile Dental', array['books@smile.ca'], 'DEN-0001', 4950::bigint, 'usd', 'America/Toronto')$$,
  'a paid invoice''s copy goes to the other addresses'
);
select is_empty($$select * from public.billing_receipt_copy('in_paid')$$, 'only once');
select is_empty($$select * from public.billing_receipt_copy('in_open')$$, 'not before it is paid');
select is_empty($$select * from public.billing_receipt_copy('in_solo')$$, 'nothing when the primary is the only address');
select isnt((select receipt_copied_at from public.billing_invoices where stripe_invoice_id = 'in_solo'), null,
  'and that invoice is marked, so a later address gets the next receipts only');

select * from finish();
rollback;
