-- MS-141 · Billing emails and invoices: who may read and change the addresses, how they are kept, that a read-only
-- clinic may still change them, the first address pinned to the one the Stripe customer bills, the receipt copy the
-- webhook sends once per paid invoice, and an invoice whose charge failed.
begin;
select plan(32);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000020401', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000020402', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000020403', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'solo@dentory.test'),
  ('00000000-0000-4000-8000-000000020404', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'anna@dentory.test'),
  ('00000000-0000-4000-8000-000000020405', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bob@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, trial_ends_at, stripe_customer_id) values
  ('00000000-0000-4000-8000-000000020411', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', now() - interval '1 day', 'cus_smile'),
  ('00000000-0000-4000-8000-000000020412', 'Solo Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '60 days', 'cus_solo'),
  ('00000000-0000-4000-8000-000000020413', 'Pin Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '60 days', null);
insert into public.memberships (clinic_id, user_id, email, full_name, role, status, invited_at) values
  ('00000000-0000-4000-8000-000000020411', '00000000-0000-4000-8000-000000020401', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active', now() - interval '10 days'),
  ('00000000-0000-4000-8000-000000020411', '00000000-0000-4000-8000-000000020402', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active', now() - interval '5 days'),
  ('00000000-0000-4000-8000-000000020412', '00000000-0000-4000-8000-000000020403', 'solo@dentory.test', 'Solo Admin', 'admin', 'active', now() - interval '30 days'),
  ('00000000-0000-4000-8000-000000020413', '00000000-0000-4000-8000-000000020404', 'anna@dentory.test', 'Anna Lopez', 'admin', 'active', now() - interval '20 days'),
  ('00000000-0000-4000-8000-000000020413', '00000000-0000-4000-8000-000000020405', 'bob@dentory.test', 'Bob Chen', 'admin', 'active', now() - interval '10 days');

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

select ok(not has_function_privilege('authenticated', 'public.billing_receipt_copy(text, text)', 'execute'),
  'members cannot claim a receipt copy');
select ok(not has_function_privilege('authenticated', 'public.billing_receipt_finish(text, boolean)', 'execute'),
  'nor mark one sent');
select ok(not has_function_privilege('authenticated', 'public.billing_invoice_payment_failed(text)', 'execute'),
  'nor mark a payment failed');

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

-- The first address is the one the Stripe customer was created with, whoever leaves the clinic later.
select is(public.billing_set_customer('00000000-0000-4000-8000-000000020413', 'cus_pin'), 'cus_pin', 'the customer is kept');
select is((select billing_emails from public.clinics where id = '00000000-0000-4000-8000-000000020413'),
  array['anna@dentory.test'], 'with the address Stripe bills as the list''s first');
update public.memberships set role = 'staff' where user_id = '00000000-0000-4000-8000-000000020404';
select pg_temp.act_as('00000000-0000-4000-8000-000000020405');
select is(public.billing_emails_list('00000000-0000-4000-8000-000000020413'), array['anna@dentory.test'],
  'so the sheet still starts with it once Anna is Staff');
select is(public.billing_emails_save('00000000-0000-4000-8000-000000020413', array['bob@dentory.test']),
  array['anna@dentory.test', 'bob@dentory.test'], 'and Bob adds his address after it');
reset role;
select public.billing_set_customer('00000000-0000-4000-8000-000000020411', 'cus_other');
select is((select array[stripe_customer_id] || billing_emails from public.clinics where id = '00000000-0000-4000-8000-000000020411'),
  array['cus_smile', 'sarah@dentory.test', 'books@smile.ca'], 'a clinic''s customer and saved list are kept as they are');

-- The receipt copy, once per paid invoice, to every billing email but the one Stripe sent its receipt to.
insert into public.billing_invoices (clinic_id, stripe_invoice_id, number, issued_at, amount_cents, currency, status, hosted_url) values
  ('00000000-0000-4000-8000-000000020411', 'in_paid', 'DEN-0001', '2027-01-06 14:00+00', 4950, 'usd', 'paid', 'https://invoice.stripe.com/i/1'),
  ('00000000-0000-4000-8000-000000020411', 'in_open', 'DEN-0002', '2027-02-06 14:00+00', 4950, 'usd', 'open', null),
  ('00000000-0000-4000-8000-000000020412', 'in_solo', 'DEN-0003', '2027-01-06 14:00+00', 9900, 'usd', 'paid', null),
  ('00000000-0000-4000-8000-000000020411', 'in_moved', 'DEN-0004', '2027-03-06 14:00+00', 4950, 'usd', 'paid', null),
  ('00000000-0000-4000-8000-000000020411', 'in_unknown', 'DEN-0005', '2027-04-06 14:00+00', 4950, 'usd', 'paid', null);
select results_eq(
  $$select clinic_name, emails, number, amount_cents, currency, time_zone
    from public.billing_receipt_copy('in_paid', ' Sarah@Dentory.test ')$$,
  $$values ('Smile Dental', array['books@smile.ca'], 'DEN-0001', 4950::bigint, 'usd', 'America/Toronto')$$,
  'a paid invoice''s copy goes to every address but the one Stripe sent its receipt to'
);
select throws_ok($$select * from public.billing_receipt_copy('in_paid', 'sarah@dentory.test')$$, '55P03',
  'The receipt copy is being sent', 'not twice while it is being sent: that delivery fails, so Stripe tries again later');
select public.billing_receipt_finish('in_paid', false);
select is((select count(*)::integer from public.billing_receipt_copy('in_paid', 'sarah@dentory.test')), 1,
  'a failed send frees it for Stripe''s retry of the event');
update public.billing_invoices set receipt_copy_claimed_at = now() - interval '11 minutes' where stripe_invoice_id = 'in_paid';
select is((select count(*)::integer from public.billing_receipt_copy('in_paid', 'sarah@dentory.test')), 1,
  'as does a claim left for 10 minutes');
select public.billing_receipt_finish('in_paid', true);
select is_empty($$select * from public.billing_receipt_copy('in_paid', 'sarah@dentory.test')$$, 'once sent, never again');
select isnt((select receipt_copied_at from public.billing_invoices where stripe_invoice_id = 'in_paid'), null,
  'the invoice is marked sent');
select is_empty($$select * from public.billing_receipt_copy('in_open', 'sarah@dentory.test')$$, 'not before it is paid');
select is_empty($$select * from public.billing_receipt_copy('in_solo', 'solo@dentory.test')$$,
  'nothing when Stripe''s address is the only one');
select isnt((select receipt_copied_at from public.billing_invoices where stripe_invoice_id = 'in_solo'), null,
  'and that invoice is marked, so a later address gets the next receipts only');
select is((select emails from public.billing_receipt_copy('in_moved', 'anna@old-owner.test')),
  array['sarah@dentory.test', 'books@smile.ca'], 'Stripe billing an address off the list: every listed one gets the copy');
select is((select emails from public.billing_receipt_copy('in_unknown', null)), array['books@smile.ca'],
  'without Stripe''s address, the list''s first is taken as Stripe''s');

-- A charge that failed.
select public.billing_invoice_payment_failed('in_open');
select ok((select payment_failed and status = 'open' from public.billing_invoices where stripe_invoice_id = 'in_open'),
  'an open invoice Stripe could not charge is marked, for Invoices to say Failed');
select ok(not (select payment_failed from public.billing_invoices where stripe_invoice_id = 'in_paid'),
  'others are not');

select * from finish();
rollback;
