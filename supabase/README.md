# Database and functions

Supabase project files: `config.toml` (local stack), `migrations/` (one timestamped SQL file per change, applied in order), `seed.sql` (runs after the migrations on every reset; empty for now), `seed-demo.sql` (the demo clinic from the design, MS-109), `functions/` (Deno Edge Functions, one folder per function, shared code under `_shared/`), `tests/database/` (pgTAP tests, one file per table, policy or RPC).

Commands are in the root `Makefile` (`make db-start db-reset db-test seed-demo`; `make db-reset seed-demo` gives a fresh demo clinic; `make functions-check` type-checks the functions and runs their Deno tests, the `*_test.ts` files). Linking and pushing to the hosted projects is described in the root `README.md`.

## Edge Functions

| Function | Called by | What it does |
|---|---|---|
| `health` | nobody | `GET` answers `{ "ok": true }` so the stack and the Deno toolchain can be checked. |
| `invite_member` | the app, as a signed-in admin | `POST { clinic_id, email, role?, full_name? }`: records the invited membership with a fresh 7-day token through `invitation_create` (only the SHA-256 of the token is stored) and emails the invitee the link `https://app.dentory.ca/invite?token=…`. Calling it again for the same address resends with a new token; the old link stops working (MS-112). |
| `accept_invitation` | the Join screen, before the invitee has an account (`verify_jwt = false`) | `POST { token, full_name, password }`: reads the invitation (`invitation_lookup`), creates the account confirmed (or, after `invitation_check` says the account may join, sets the password of the account that already has the address) and makes the membership active (`invitation_accept`). A refusal (another clinic, another address, a seat already taken) answers 409 with the server's sentence and changes nothing; an expired or used link answers 410. The app then signs in with the address and password. |
| `billing_checkout` | Grigor at onboarding and the billing emails, with the service role key (MS-100 D18: the app opens no payment page) | `POST { clinic_id }` answers `{ url }`: Stripe Checkout in subscription mode for the clinic's Stripe customer (created here the first time, with the clinic's name and first billing email), the $99 monthly price, the 50% lifetime coupon for a clinic with `promo_lifetime_50`, and `trial_end` at the clinic's trial end when it is more than 48 hours away, so nothing is charged during the free months (MS-140). A clinic with a live subscription is refused (409), even one the webhook has not reported yet, which is linked then; it gets the portal link instead. A new link expires the clinic's earlier unpaid ones, so only the newest can be paid, and any link expires after 24 hours. |
| `billing_portal` | Grigor and the billing emails, with the service role key | `POST { clinic_id }` answers `{ url }`: the Stripe Customer Portal of the clinic's customer, where the card changes (MS-140). Refused (409) before a subscription exists. |
| `stripe_webhook` | Stripe (`verify_jwt = false`) | Checks the `Stripe-Signature` header with `STRIPE_WEBHOOK_SECRET`, then reads the subscription or invoice back from Stripe, so late or out-of-order events do no harm: subscription events set the clinic's status, next payment and card (`billing_apply_subscription`, `billing_apply_card`); `customer.updated` changes the card; invoice events keep the invoices (`billing_record_invoice`; the $0 one that opens a trial is not kept, and a paid one never goes back to open); `checkout.session.completed` links a new subscription to its clinic. A card on file keeps the clinic writable through and after its trial (Stripe's `trialing` and `active` are `active`). An invoice whose charge failed (`invoice.payment_failed` while it is open) is marked (`billing_invoice_payment_failed`), so Invoices says Failed. Once an invoice is paid, every billing email but the one Stripe sent its receipt to gets Dentory's copy, once and in one Resend call (`billing_receipt_copy` claims it, `billing_receipt_finish` marks it sent; a failed send answers 500, and a delivery that finds the copy being sent answers 409, so Stripe tries the event again), MS-141: Stripe's API keeps one address per customer, the first billing email. |
| `send_digest` | the database's hourly job (`engine.digest_dispatch`, `verify_jwt = false`, the service role key checked), and Grigor to try the email | `POST {}`: claims the weekly digests that are due (`digest_claim`: Monday 7 am to noon at each clinic with Email digest on, not a read-only clinic, the switch read again), emails each to the clinic's active admins (`_shared/digest-email.ts`) and records which went out (`digest_finish`); one that reached nobody is retried by the next hour, and one queued more than 6 hours ago is dropped (MS-145). `POST { clinic_id }` sends that clinic's digest as it reads now to its admins, whatever the day and the switch, and records nothing: how to see the email in Gmail or Apple Mail on a hosted project. |
| `export_csv` | the app, as a signed-in admin (Account, Export CSV) | `POST { clinic_id }`: starts an export job (`export_job_start`: admins only, one per clinic every 10 minutes, a read-only clinic included) and answers `{ email }` at once; then, in the background, reads the clinic's rows in one snapshot (`export_data`), writes `products.csv`, `batches.csv` and `transactions.csv` (UTF-8 with a byte order mark, CRLF, dates at the clinic's time), zips them into the private `exports` bucket as `{clinic_id}/{job_id}.zip`, emails the admin a signed download link valid 7 days (or, if the export fails, an email saying so) and closes the job (`export_job_finish`). An admin whose colleague exported in the last 10 minutes is told whose export it was and where it went. Each export removes the clinic's zips whose links have expired (MS-143). |
| `extract_invoice` | the app, as a signed-in admin, right after `invoice_create` (Review invoice) | `POST { invoice_id }`: claims the invoice's reading once (`invoice_reading_start`: an admin of its clinic, a clinic that may write, an invoice not read yet) and answers 202 at once; then, in the background, downloads its pages from the private `invoices` bucket (`{clinic_id}/{invoice_id}/page-n.jpg` or `page-1.pdf`), reads them with the Claude API (`claude-sonnet-5-5`, structured outputs to the extraction schema, `reading.ts`) and hands the result to `invoice_reading_finish`, which matches the lines against the clinic's products without AI, saves them and marks the invoice ready with its alert and the admins' push; a reading that fails, or runs past 60 seconds, is recorded with its reason (`invoice_reading_fail`). Invoice contents never reach the log (MS-129). |

Every function answers refusals as `{ "error": { "code", "message", "field"? } }` with the HTTP status the app maps in `Core/Data/AppError+Functions.swift` (`supabase/functions/_shared/http.ts`).

### Secrets and settings

The local runtime injects `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` by itself. The hosted project needs, set once with `supabase secrets set NAME=value` (never in the repo or in a chat):

| Secret | Used by | Value |
|---|---|---|
| `ANTHROPIC_API_KEY` | `extract_invoice` | A Claude API key (Claude Console, API keys). Without it, as on the local stack, every reading fails at once with the reason error. |
| `RESEND_API_KEY` | `invite_member`, `export_csv`, `stripe_webhook`, `send_digest` | A Resend API key for the `dentory.ca` sending domain (Resend, API keys). Without it the function sends nothing and writes the email, link included, to its log; that is how the local stack runs. |
| `EMAIL_FROM` | `invite_member`, `export_csv`, `stripe_webhook`, `send_digest` | Optional. Defaults to `Dentory <invites@dentory.ca>`; the domain must be verified in Resend (SPF and DKIM records at the registrar). |
| `APP_LINK_BASE` | `invite_member`, `send_digest` | Optional. Defaults to `https://app.dentory.ca`, the universal-link host (`applinks/README.md`). |
| `STRIPE_SECRET_KEY` | the billing functions | The Stripe secret key: `sk_test_…` on staging, `sk_live_…` on prod. Without it `billing_checkout` and `billing_portal` answer 503 "Billing isn't set up yet. Try again later.", as on the local stack. |
| `STRIPE_PRICE_ID` | `billing_checkout` | The `price_…` of the product "Dentory clinic": $99 USD, recurring monthly. |
| `STRIPE_PROMO_COUPON_ID` | `billing_checkout` | The coupon for the lifetime promotion: 50% off, duration forever. Needed once a clinic has `promo_lifetime_50`. |
| `STRIPE_WEBHOOK_SECRET` | `stripe_webhook` | The `whsec_…` signing secret of the webhook endpoint below. |
| `BILLING_RETURN_URL` | the billing functions | Optional. Defaults to `https://app.dentory.ca/billing/done`, the page Checkout and the Customer Portal return to (`applinks/billing/done`). |

Deploy with `supabase functions deploy invite_member`, `supabase functions deploy export_csv`, `supabase functions deploy extract_invoice`, `supabase functions deploy accept_invitation --no-verify-jwt` and `supabase functions deploy send_digest --no-verify-jwt` (the setting also lives in `config.toml`).

### Invoice reading (MS-129)

`extract_invoice` reads with the project's `ANTHROPIC_API_KEY` (above); set it, push the migration and deploy the
function. The ticket's target, half the readings under 20 seconds, can only be measured with a key:

- `ANTHROPIC_API_KEY=… make invoice-reading-live` reads the five synthetic invoices in
  `functions/extract_invoice/fixtures` with the real API (a few cents), checks what comes back against the recorded
  answers and that no personal data came back, and prints each reading's time and the median, which must be under 20
  seconds. `RECORD=1` writes the live answers over the recorded ones instead (`fixtures/README.md`).
- On a hosted project, the median of real readings, from the upload to the result, counting the invoices read
  (failed ones have a `read_at` too) and leaving out the demo clinic's seeded invoice:
  `select percentile_cont(0.5) within group (order by extract(epoch from read_at - created_at)) from invoices where read_at is not null and status in ('ready', 'confirmed') and clinic_id <> 'd0000000-0000-4000-8000-000000000001';`

The tests need no key: `make functions-check` replays the recorded answers (`reading_test.ts`), and
`40_invoice_matching_test.sql` matches their lines against the demo catalog. The local stack has no key either: there
`extract_invoice` reads the five fixture invoices from their recorded answers (`replay.ts`, MS-136), chosen by the
SHA-256 of the pages, and fails any other pages with the reason error. The app uploads a PDF as it is, so a fixture PDF
picked on Upload PDF or image is read end to end on the simulator, as `make e2e` does; images are re-encoded as they are
captured and never match. A hosted project never replays (its `SUPABASE_URL` is not the local gateway, `kong`): without
its key every reading fails there. To read real invoices on the local stack, put the key in the git-ignored
`supabase/functions/.env` and run `supabase functions serve --env-file supabase/functions/.env`. Each minute `engine.invoice_reading_timeout`
fails a reading that never started or ran past its time, so no invoice stays "Reading invoice".

### Weekly digest (MS-145)

The hourly job calls `send_digest` with the URL and key it finds in Vault, the same `project_url` and `service_role_key` secrets `send_push` uses (build state, item 9); without them the digests stay queued and nothing is sent, and once the function first runs, every digest queued more than 6 hours earlier is dropped rather than sent late. To see a clinic's digest now, in the inbox of each of its admins:

```bash
curl -X POST "https://<project-ref>.supabase.co/functions/v1/send_digest" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H "Content-Type: application/json" \
  -d '{"clinic_id": "<clinic id>"}'
```

Locally, `supabase functions serve` and the same call on `http://127.0.0.1:54321` write the email to the function's log instead. `select public.digest_preview('<clinic id>');` in the SQL editor shows what the email will say.

### Stripe (MS-140, once per project, by hand)

1. In the Stripe dashboard (test mode for staging): a product "Dentory clinic" with a $99 USD monthly price, and a coupon of 50% off, forever.
2. Settings, Billing, Customer portal: let customers update their payment method and see invoices, then save the configuration (the portal answers an error until one is saved).
3. Settings, Business, Customer emails: under Payments, turn on Successful payments. Stripe then emails each paid invoice's receipt to the customer's address, the clinic's first billing email, which Dentory's own copies leave out (MS-141); with it off, that address gets no receipt. Stripe sends no automatic receipt for test payments, so on staging only the other billing emails get one (Dentory's copy).
4. Developers, Webhooks: an endpoint at `https://<project-ref>.supabase.co/functions/v1/stripe_webhook` for `checkout.session.completed`, `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`, `customer.subscription.paused`, `customer.subscription.resumed`, `customer.updated`, `invoice.finalized`, `invoice.paid`, `invoice.payment_failed`, `invoice.voided` and `invoice.marked_uncollectible`; its signing secret is `STRIPE_WEBHOOK_SECRET`.
5. `supabase secrets set STRIPE_SECRET_KEY=… STRIPE_PRICE_ID=… STRIPE_PROMO_COUPON_ID=… STRIPE_WEBHOOK_SECRET=…`, then `supabase functions deploy billing_checkout`, `supabase functions deploy billing_portal` and `supabase functions deploy stripe_webhook --no-verify-jwt`. The page functions accept only the service role key, the legacy `service_role` JWT the functions see as `SUPABASE_SERVICE_ROLE_KEY`.
6. Grant a clinic the lifetime promotion with `update clinics set promo_lifetime_50 = true where id = '…';` in the SQL editor; the app never changes it.

A clinic's links, from a terminal with the project's service role key in an environment variable (never pasted in a chat):

```
curl -s -X POST "https://<project-ref>.supabase.co/functions/v1/billing_checkout" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" -H "Content-Type: application/json" \
  -d '{"clinic_id": "<clinic id>"}'
```

`billing_portal` answers the same way once the clinic has a subscription. On staging, the Checkout page takes the test card `4242 4242 4242 4242` with any future date and CVC; Billing in the app shows the card once the webhook lands, on its next return to the foreground or pull to refresh.

### Trying an invitation locally

1. `make db-start`, `make db-reset seed-demo`, run the Debug build, sign in as sarah@smiledental.ca (Admin, password `smiledental`) or sign up a new clinic and invite someone at step 3; or call the function by hand with a signed-in user's token.
2. `make invite-links` prints the links from the function log, as `dentory://invite?token=…`.
3. `xcrun simctl openurl booted "dentory://invite?token=…"` opens the Join screen on the running simulator. The universal `https://app.dentory.ca/invite?token=…` form needs the domain and the Apple team id (`applinks/README.md`).

## Password reset email (MS-113)

Supabase Auth sends it, not an Edge Function. Its template is `templates/recovery.html` (`[auth.email.template.recovery]` in `config.toml`): the link is `dentory://reset-password?token_hash=…&type=recovery` when the app sent `redirect_to=dentory://reset-password` (Debug builds, `Config/Debug.xcconfig`) and the universal `https://app.dentory.ca/reset-password?token_hash=…&type=recovery` otherwise. The app verifies the token hash with `verifyOTP(type: .recovery)`, so the link works on any device that has the app, with no PKCE code stored on the one that asked. An expired or used link answers `otp_expired`; the app offers a new one.

### Trying it locally

1. `make db-start`, `make db-reset seed-demo`, run the Debug build signed out, tap Forgot password, enter sarah@smiledental.ca and tap Send link.
2. Open the local mail catcher at http://127.0.0.1:54324 in the simulator's Safari and tap Set a new password in the newest email: the simulator asks to open Dentory, which shows Set a new password. From the Mac, copy the link from the email and run `xcrun simctl openurl booted "dentory://reset-password?token_hash=…&type=recovery"`.
3. Save a new password of at least 8 characters: Home opens with the toast "Password updated". Opening the same link again shows "This link has expired".

### Hosted projects (once per project, by hand)

- Authentication, Emails, SMTP Settings: turn on custom SMTP with Resend (host `smtp.resend.com`, port 465, user `resend`, password a Resend API key, sender `Dentory <noreply@dentory.ca>` on the verified domain). Supabase's own mailer only writes to the project team's addresses and a few emails an hour, so without this clinics get no reset email.
- Authentication, URL Configuration, Redirect URLs: add `https://app.dentory.ca/reset-password` (and `dentory://reset-password` on staging if a Debug build points at it).
- Authentication, Emails, Reset password: subject "Reset your Dentory password", body the whole of `templates/recovery.html`. `supabase config push` would also send it, together with the rest of `config.toml`, so the dashboard is the safer way.
- The universal link needs `applinks/` served on `app.dentory.ca` with the Apple team id (`applinks/README.md`). Until that domain is live the hosted emails' links lead nowhere, the same open item as the invitation links.

