-- MS-140 · Billing: the admin's summary (f34), the account billing_checkout and billing_portal work from, and what the
-- Stripe webhook writes: the customer, the subscription's status and next payment, the card, the invoices.
begin;
select plan(30);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000016401', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000016402', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000016403', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'solo@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, trial_ends_at, promo_lifetime_50) values
  ('00000000-0000-4000-8000-000000016411', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '80 days', true),
  ('00000000-0000-4000-8000-000000016412', 'Solo Dental', 'CA', 'CAD', 'America/Toronto', now() + interval '60 days', false);
insert into public.memberships (clinic_id, user_id, email, full_name, role, status, invited_at) values
  ('00000000-0000-4000-8000-000000016411', '00000000-0000-4000-8000-000000016401', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active', now() - interval '10 days'),
  ('00000000-0000-4000-8000-000000016411', '00000000-0000-4000-8000-000000016402', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active', now() - interval '5 days'),
  ('00000000-0000-4000-8000-000000016412', '00000000-0000-4000-8000-000000016403', 'solo@dentory.test', 'Solo Admin', 'admin', 'active', now() - interval '30 days');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

select ok(not has_function_privilege('anon', 'public.billing_summary(uuid)', 'execute'), 'anon cannot read billing');
select ok(not has_function_privilege('authenticated', 'public.billing_account(uuid, uuid)', 'execute'),
  'members cannot read the Stripe account');
select ok(not has_function_privilege('authenticated', 'public.billing_apply_subscription(text, text, text, timestamptz, uuid)', 'execute'),
  'members cannot write a subscription');
select ok(not has_function_privilege('authenticated', 'public.billing_apply_card(text, text, text)', 'execute'),
  'members cannot write a card');

-- The admin's summary during the trial, before any card.
select pg_temp.act_as('00000000-0000-4000-8000-000000016401');
select results_eq(
  $$select subscription_status::text, has_subscription, promo_lifetime_50, card_brand, card_last4, invoice_count, billing_email,
           billing_email_count
    from public.billing_summary('00000000-0000-4000-8000-000000016411')$$,
  $$values ('trialing', false, true, null::text, null::text, 0, 'sarah@dentory.test', 1)$$,
  'a new clinic is on its trial with no card, and bills the first admin'
);
select ok((select abs(extract(epoch from trial_ends_at - (now() + interval '80 days'))) < 1
  from public.billing_summary('00000000-0000-4000-8000-000000016411')), 'with the trial''s end');
reset role;
update public.clinics set billing_emails = array['owner@dentory.test', 'books@dentory.test']
where id = '00000000-0000-4000-8000-000000016411';
select pg_temp.act_as('00000000-0000-4000-8000-000000016401');
select results_eq(
  $$select billing_email, billing_email_count from public.billing_summary('00000000-0000-4000-8000-000000016411')$$,
  $$values ('owner@dentory.test', 2)$$,
  'the clinic''s own billing emails come first'
);
reset role;

-- Staff and another clinic's admin see no billing.
select pg_temp.act_as('00000000-0000-4000-8000-000000016402');
select throws_ok($$select * from public.billing_summary('00000000-0000-4000-8000-000000016411')$$,
  '42501', 'Only an admin can see billing', 'Staff do not see billing');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000016403');
select throws_ok($$select * from public.billing_summary('00000000-0000-4000-8000-000000016411')$$,
  '42501', 'Only an admin can see billing', 'another clinic''s admin does not either');
reset role;

-- What billing_checkout and billing_portal start from.
select throws_ok(
  $$select * from public.billing_account('00000000-0000-4000-8000-000000016411', '00000000-0000-4000-8000-000000016402')$$,
  '42501', 'Only an admin can manage billing', 'Staff cannot open Checkout'
);
select results_eq(
  $$select clinic_name, stripe_customer_id, stripe_subscription_id, promo_lifetime_50, billing_email
    from public.billing_account('00000000-0000-4000-8000-000000016411', '00000000-0000-4000-8000-000000016401')$$,
  $$values ('Smile Dental', null::text, null::text, true, 'owner@dentory.test')$$,
  'the admin''s account has no Stripe customer yet'
);
select is(public.billing_set_customer('00000000-0000-4000-8000-000000016411', 'cus_smile'), 'cus_smile',
  'the new customer is kept');
select is(public.billing_set_customer('00000000-0000-4000-8000-000000016411', 'cus_twice'), 'cus_smile',
  'a customer created meanwhile gives way to the kept one');

-- The webhook: Checkout with a card during the trial, then the card itself.
select is(public.billing_apply_subscription('cus_smile', 'sub_1', 'trialing', '2027-01-06 12:00:00+00'),
  '00000000-0000-4000-8000-000000016411'::uuid, 'a subscription is matched to its clinic by the customer');
select results_eq(
  $$select subscription_status::text, stripe_subscription_id from public.clinics where id = '00000000-0000-4000-8000-000000016411'$$,
  $$values ('active', 'sub_1')$$,
  'a card on file during the trial makes the clinic active, so writes go on after the trial'
);
select is(public.billing_apply_card('cus_smile', 'visa', '4242'), '00000000-0000-4000-8000-000000016411'::uuid,
  'the card is matched the same way');
select is(public.billing_apply_subscription('cus_nobody', 'sub_x', 'active', now()), null, 'an unknown customer changes nothing');
select pg_temp.act_as('00000000-0000-4000-8000-000000016401');
select results_eq(
  $$select has_subscription, card_brand, card_last4, current_period_end from public.billing_summary('00000000-0000-4000-8000-000000016411')$$,
  $$values (true, 'visa', '4242', '2027-01-06 12:00:00+00'::timestamptz)$$,
  'the admin then sees the card and the next payment'
);
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000016402');
select is((select count(*)::integer from public.clinic_billing), 0, 'Staff read no card');
reset role;

-- Payment trouble and the end of a subscription.
select public.billing_apply_subscription('cus_smile', 'sub_1', 'past_due', '2027-02-06 12:00:00+00');
select is((select subscription_status::text from public.clinics where id = '00000000-0000-4000-8000-000000016411'), 'past_due',
  'a failed payment is past due while Stripe retries');
select public.billing_apply_subscription('cus_smile', 'sub_1', 'unpaid', '2027-02-06 12:00:00+00');
select ok(not public.clinic_can_write('00000000-0000-4000-8000-000000016411'), 'unpaid makes the clinic read-only');
select public.billing_apply_subscription('cus_smile', 'sub_old', 'canceled', null);
select is((select stripe_subscription_id from public.clinics where id = '00000000-0000-4000-8000-000000016411'), 'sub_1',
  'an older subscription ending changes nothing');
select public.billing_apply_subscription('cus_smile', 'sub_1', 'canceled', null);
select results_eq(
  $$select subscription_status::text, stripe_subscription_id from public.clinics where id = '00000000-0000-4000-8000-000000016411'$$,
  $$values ('trialing', null::text)$$,
  'a subscription that ends during the free months leaves the trial running, ready for a new Checkout'
);
update public.clinics set trial_ends_at = now() - interval '1 day' where id = '00000000-0000-4000-8000-000000016411';
select public.billing_apply_subscription('cus_smile', 'sub_2', 'active', '2027-03-06 12:00:00+00');
select public.billing_apply_subscription('cus_smile', 'sub_2', 'canceled', null);
select is((select subscription_status::text from public.clinics where id = '00000000-0000-4000-8000-000000016411'), 'canceled',
  'one that ends after them cancels the plan');
select ok(not public.clinic_can_write('00000000-0000-4000-8000-000000016411'), 'and the clinic is read-only');

-- Checkout completed for a clinic whose customer was not kept yet: the clinic comes from the session.
select is(public.billing_apply_subscription('cus_solo', 'sub_solo', 'active', now() + interval '1 month',
  '00000000-0000-4000-8000-000000016412'), '00000000-0000-4000-8000-000000016412'::uuid,
  'Checkout names its clinic');
select is((select stripe_customer_id from public.clinics where id = '00000000-0000-4000-8000-000000016412'), 'cus_solo',
  'and its customer is kept');

-- Invoices.
select public.billing_record_invoice('cus_smile', 'in_1', 'DENT-0001', '2027-01-06 12:00:00+00', 4950, 'USD', 'open',
  'https://invoice.stripe.com/i/1', 'https://pay.stripe.com/invoice/1/pdf');
select public.billing_record_invoice('cus_smile', 'in_1', 'DENT-0001', '2027-01-06 12:00:00+00', 4950, 'USD', 'paid',
  'https://invoice.stripe.com/i/1', 'https://pay.stripe.com/invoice/1/pdf');
select results_eq(
  $$select number, amount_cents, currency, status from public.billing_invoices where clinic_id = '00000000-0000-4000-8000-000000016411'$$,
  $$values ('DENT-0001', 4950::bigint, 'usd', 'paid')$$,
  'an invoice is kept once and brought up to date'
);
select pg_temp.act_as('00000000-0000-4000-8000-000000016401');
select is((select invoice_count from public.billing_summary('00000000-0000-4000-8000-000000016411')), 1,
  'and the admin counts it');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000016402');
select is((select count(*)::integer from public.billing_invoices), 0, 'Staff read no invoice');
reset role;

select * from finish();
rollback;
