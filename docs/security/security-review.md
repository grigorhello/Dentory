# Security review before launch (MS-151)

Ticket MS-151 (#122), run on 2026-10-26 against the default branch at `ef1fd7c` (everything merged up to MS-136's audit fixes, #207). Line numbers below are those of `ef1fd7c` unless a line says it points at this PR's code. The fixes are in the same pull request as this report.

MS-146 (#208) merged during the review. Its `20261021120000_invoice_file_delete.sql` was read against the same rules: `invoice_file_delete` is security definer on an empty search path, revoked from public and anon, and it checks for an admin of a clinic that may write and a received invoice. `46_…` passes with it.

## Result

One high finding: an admin could forge an invitation token and use it to set the password of another person's account. It is fixed, with tests. One medium finding, the direct writes to a clinic's settings that #122's note describes, is fixed too. Of the eleven low findings, six are fixed, four are accepted with their reasons, and one is a recommended app follow-up. The hosted projects' settings that no code can set are listed under "Open items for Grigor".

| ID | Severity | Finding | Status |
|---|---|---|---|
| F1 | High | An admin could write membership rows directly and forge an invitation, then set the password of a colleague's or a dormant account through `accept_invitation` | Fixed |
| F2 | Medium | An admin could write the clinic's settings and billing emails directly, past `clinic_settings_save` and `billing_emails_save`, and `clinic_create` kept any time zone; a zone Postgres does not know stops the nightly refresh of every clinic | Fixed |
| F3 | Low | Without `RESEND_API_KEY`, a hosted project's function log would hold invitation links, export download links and addresses | Fixed |
| F4 | Low | A password reset link replaces the session on the device as soon as it opens, and Set a new password names no account | Open, follow-up recommended |
| F5 | Low | Staff could read their clinic's billing columns (Stripe ids, promotion, billing emails) | Fixed |
| F6 | Low | Invitations had no limit: any admin, so anyone who signs up, could send unlimited emails from dentory.ca | Fixed (30 an hour per clinic, 3 per clinic to one address) |
| F7 | Low | Sentry recorded every request's address and each 5xx request, whatever the app's own breadcrumb rule said | Fixed |
| F8 | Low | The anon key could execute six functions it never needs | Fixed |
| F9 | Low | Auth settings: the hosted projects' password length, password change and email limits are dashboard settings | Local fixed, hosted open |
| F10 | Low | Invitation and reset tokens can travel over the `dentory://` scheme, which another app could also claim | Accepted until universal links work |
| F11 | Low | Third-party CI actions are pinned to tags, not commit SHAs | Accepted |
| F12 | Low | Two refusal sentences carry an email address, so they reach the Postgres log | Accepted |
| F13 | Low | The session in the Keychain survives deleting the app | Accepted |

## How the review ran

- **The `security-review` skill**, on the whole repository rather than a diff, as three passes run in parallel:
  - the database (all 38 migrations, each object judged by its last definition, the seed files and `config.toml`);
  - the Edge Functions, the email templates, `applinks/` and `site/`;
  - the app, `project.yml`, `Config/`, the CI workflows, the `Makefile` and the git history, for secrets.
- **A false-positive pass per candidate**, with the skill's exclusions and precedents. Only F1 scored 8 or more out of 10, so it alone counts as a confirmed vulnerability under the skill's rules (10/10). F3, F4, F5, F10 and F11 scored 2 to 5, as hardening or as conditions an attacker cannot bring about.
- **Where the rest came from.**
  - F2 is #122's note, and running it on the database found the second way in.
  - F6 to F9, F12 and F13 came from the passes' notes and from checking the ticket's items one by one.

  They are kept here because the ticket asks for each item it lists, or because the fix is cheap.
- **The ticket's checklist**, verified item by item (below), with the note on #122 from the MS-139 review.
- **The database checks ran on a local database.** MS-146's builder held the shared stack, so this ran as a database of its own (the same `supabase db start`, `db reset` and `test db` as `make db-reset db-test`, with another project id and ports), then again after `seed-demo.sql`. It covered the pgTAP suite, the time zone case of F2, and the grants and functions the checklist cites.

## Findings

### F1 · Forged invitation tokens (High, fixed)

- **Where.**
  - `supabase/migrations/20261016130000_access.sql:140` granted insert, update and delete on `public.memberships` to `authenticated`, every column. The policies at lines 178-184 checked only `is_admin(clinic_id) and clinic_can_write(clinic_id)`, and no later migration narrowed them.
  - `accept_invitation` (`supabase/functions/accept_invitation/index.ts:31-66`, no JWT, `config.toml:388-389`) treats a row's `invite_token_hash` as proof that the email reached its address. When an account has that address, it calls `invitation_check` and then sets the account's password (`updateUserById`, line 49). Otherwise it creates the account already confirmed (line 57).
  - `invitation_check` (`20261019020000_invitations.sql:169-211`) refuses only an account that is active in another clinic, or that has a second row in the same clinic.
- **What could happen.**
  - Anyone can sign up and open a clinic, which makes them its admin, writable for the trial.
  - With the anon key and their own token, they `PATCH` a colleague's membership row to `status: invited` with `invite_token_hash = sha256(T)`, for a token T they chose. Or they `POST` an invited row for any address. Then they call `accept_invitation` with T and a password of their choosing.
  - That takes over a colleague's account in their own clinic, another admin included, silently. It also takes over any account not active in another clinic: a removed member, or someone who signed up and stopped before creating a clinic.
  - For an address without an account, they get a confirmed account that no mailbox ever approved.
- **Fix** (`20261021130000_security_review.sql`, F1).
  - `authenticated` keeps no insert, update or delete on memberships but `update (role)`, which `team_set_role` needs because it runs as the caller. The insert and delete policies are dropped.
  - Every membership is written by a function that checks what it writes:
    - `invitation_create` and `invitation_accept` (the Edge Functions, as service role);
    - `clinic_create`;
    - `team_remove`;
    - `team_set_role`.
- **Tests.**
  - `47_security_review_test.sql` checks that an admin can no longer:
    - write an invited row with their own token;
    - turn a colleague back into an invitation;
    - move a seat to another account;
    - change an invited address;
    - delete a member.
    It also checks that the role stays writable, and that `invitation_check` reads a made-up token as expired, so `accept_invitation` sets no password with it.
  - `05_access_test.sql` now expects these refusals where it used to expect a direct invite or delete to pass.

### F2 · Clinic settings written directly, and unknown time zones (Medium, fixed)

- **Where.** `20261016130000_access.sql:137-138` let an admin update `name, city, country, currency, time_zone, expiry_thresholds, email_digest, billing_emails` directly. `clinic_settings_save` (`20261020160000_clinic_settings.sql:49`) and `billing_emails_save` (`20261020220000_billing_emails.sql`) were bypassed: their checks (a time zone Postgres knows, the admin's address first) and the product refresh a new expiry warning or time zone needs.
- **A second way in.** `clinic_create` (`20261017160000_onboarding.sql:87`) checked only the characters of the time zone sign-up sends, which is the device's, so anyone could make a clinic on a zone Postgres does not know through the API.
- **What could happen.**
  - `refresh_all_products()` (`20261016170000_product_status.sql:164-180`, pg_cron at 07:00) refreshes every clinic's products in one transaction.
  - Run on the local database: a clinic made through `clinic_create` with `Mars/Olympus_Mons` and one product never received was enough. The nightly refresh opened that product's out-of-stock alert, its push worked out the clinic's waking hours (`engine.push_waking_time`), and the time zone error stopped the refresh for every clinic. A dated batch fails the same way in `days_to_expiry`.
  - Without that job, no clinic's expiry status, alerts or To buy lines move overnight.
  - An admin could also remove the first billing email that receipts go to, or skip the refresh after changing the expiry warning.
- **Fix** (F2).
  - `authenticated` may update only `clinics.logo_path`, which `ClinicLogoStorage` writes after the upload. The app already saved everything else through the two functions. #122's note proposed keeping `billing_emails`; MS-141 then moved it to `billing_emails_save`, so it goes too.
  - `clinic_create` keeps a time zone Postgres does not know as UTC, which the admin can change in Clinic settings. It does not refuse it, because no sign-up step asks for the zone.
- **Tests.** `47_security_review_test.sql` checks:
  - the eight columns refused, the logo path written, and `clinic_settings_save` still saving;
  - a clinic made on an unknown zone keeps UTC, and the nightly refresh runs beside it, its out-of-stock product included.

  `05_access_test.sql` and `30_read_only_test.sql` use the logo path where they renamed the clinic directly.
- **Still true.** `refresh_all_products()` refreshes every clinic in one transaction with no exception handling per product. F2 closes the time zone ways in, but any other row a refresh cannot evaluate would still stop it for everyone. Running each clinic on its own is worth a later ticket.

### F3 · Links in a hosted project's function log (Low, fixed)

- **Where.** `supabase/functions/_shared/email.ts:20-25` and `:50-53`. Without `RESEND_API_KEY`, every email was written whole to the function log: the address, the subject, and the body with its link. Only the missing key decided it, not the local stack.
- **What could happen.** A hosted project without the key logs the invitation link, whose token is the only credential `accept_invitation` asks for (7 days, `_shared/invitation-email.ts:17-20`). It also logs the export's 7-day signed download link (`export_csv/index.ts:27, 60`). Anyone who reads the project's logs (its members, or any log drain added later) could join a clinic or download its data. Staging runs without the key today (build state, item 4).
- **Fix.**
  - `isLocalStack()` moved from `extract_invoice/replay.ts` to `_shared/environment.ts`, where `replay.ts` and the email helper both ask it.
  - On the local stack the log keeps the whole email, as `make invite-links` needs.
  - Elsewhere the log keeps one line saying how many emails went unsent, with no address, subject or link.
- **Tests.** `_shared/email_test.ts` (`make functions-check`).

### F4 · A reset link switches the device's account on open (Low, open)

- **Where.**
  - `Dentory/App/RootView.swift:76-91` opens Set a new password for any reset link, whoever is signed in.
  - `SetPasswordView.swift:35` verifies the link as the screen appears (`SetPasswordViewModel.swift:48-65`, `AuthService.swift:149-157`). supabase-swift's `verifyOTP` stores the returned session at once, replacing the signed-in member's.
  - The ready state says "Choose a password for your Dentory account." and has no way out but Save.
  - The device's cache and write queue stay, and the push token follows the new account.
- **What could happen.**
  - Someone signs up, requests a reset for their own address and sends the unopened link to a member of another clinic. The link is a genuine `app.dentory.ca` link.
  - One tap signs the member's device into the sender's clinic. What they then record (counts, invoice photos with supplier prices) goes there, and their pushes stop.
  - The member's own clinic stays out of reach, and they are likely to notice a clinic that is not theirs.
- **Why not fixed here.** It changes what the screen shows and when the session changes, beyond a security review's fixes.
- **Recommended follow-up (an MS-113 fix).**
  - Verify the link on a client that does not keep the session, and show the account's address ("Choose a password for sarah@smiledental.ca").
  - Sign in only once the password is saved, as the comment at `RootView.swift:25-27` already intends.
  - Give the ready state a way back to Sign in.
  - Run the Sign out clean-up (`DeviceSignOut`) whenever the signed-in user changes.

### F5 · Staff read the billing columns (Low, fixed)

- **Where.** `20261016130000_access.sql:126-131` granted select on `public.clinics` with no column list, so every member read `stripe_customer_id`, `stripe_subscription_id`, `promo_lifetime_50` and `billing_emails`. Billing is admin-only everywhere else (PRD §2; `billing_summary`, `billing_emails_list`, `clinic_billing`, `billing_invoices`).
- **Fix** (F5). Members read the clinic's other columns only, everything the session, Clinic settings and the `security_invoker` views use. `ClinicLogoStorage` updates the logo's path with `returning: .minimal`, since a row sent back would need every column. Admins keep reading billing through the admin-checked functions.
- **Tests.** `47_security_review_test.sql`: each billing column refused to Staff, the rest readable, and `billing_summary` still answering an admin.

### F6 · No limit on invitations (Low, fixed)

- **Where.** `invitation_create` (`20261019020000_invitations.sql:34-117`) had no limit. Each call is an email from dentory.ca carrying the clinic's and the inviter's names, and anyone can open a clinic.
- **Fix** (F6).
  - At most 30 invitations an hour per clinic, resends included, and 3 an hour per clinic to one address, recorded in `public.invitation_sends`. The table has row level security and no grants; the function forgets each row after the hour.
  - Counting one address across clinics would tell one clinic that another had just invited that person, so several clinics can each send it 3. Sign-up's own rate limit bounds how many clinics one person opens.
  - The refusals are "Your clinic sent 30 invitations in the last hour. Try again in an hour." and "This address got 3 invitations in the last hour. Try again in an hour." They show under the email field in the invite sheet and in sign-up's third step.
- **Tests.** `47_security_review_test.sql`: the 31st and the 4th refused, a refusal leaving no record, other addresses still invited, and an hour later the clinic invites again.

### F7 · Sentry network breadcrumbs (Low, fixed)

- **Where.** `Dentory/Core/Support/SentryErrorReporter.swift:16-25` turned automatic breadcrumbs off. But sentry-cocoa's network breadcrumbs and failed-request events (`enableNetworkBreadcrumbs`, `enableCaptureFailedRequests`) are separate options, on by default. So every request's address was recorded, and every 5xx was sent with its request.
- **Today.** Every address the app requests carries ids only, and every token travels in a body. The leak was latent, not live.
- **Fix.** Both options are off, so breadcrumbs carry the function name and the error kind only, as the file's comment says.

### F8 · Functions open to the anon key (Low, fixed)

- **Where.** Postgres lets everyone execute a new function. `clinic_create`, `currency_for_country`, `days_to_expiry`, `evaluate_product_status`, `membership_state` and `product_status_of` were never revoked from anon.
- **Why it mattered little.** None gave a signed-out caller anything: two ask for a user, and the others compute values or read tables anon cannot.
- **Fix** (F8).
  - Those six are revoked from public and anon, as the later migrations already revoke each function they make.
  - `46_security_invariants_test.sql` fails CI if anon can execute any function in `public` but `invitation_lookup`, so a function made from now on without that revoke cannot merge.

### F9 · Auth settings (Low; local fixed, hosted open)

- **Where.** `supabase/config.toml` sets the local stack only:
  - `minimum_password_length = 6` (line 188), while the app, `accept_invitation` and Set a new password ask for 8;
  - `secure_password_change = false` (234);
  - `enable_confirmations = false` (232), which MS-111's sign-up needs, since step 2 creates the clinic in the same session;
  - `max_frequency = "1s"` (236) and `email_sent = 2` (205) for reset emails.

  The hosted projects keep their own values, set in the dashboard.
- **Fix.** The local stack asks for 8 characters too. The hosted settings are open items below.
- **Accepted.** Without email confirmation, sign-up says when an address already has an account, and anyone can register an address they do not own. The owner of the address takes the account back with a password reset. But if the squatter opened a clinic with it, the account is active there: the real owner's invitation to their own clinic is refused ("This account belongs to another clinic"), and a reset does not free the address. Support then removes that membership by hand.

### F10 · Tokens over the `dentory://` scheme (Low, accepted for now)

- **Where.**
  - Release builds register `dentory` (`Dentory/Resources/Info.plist:24-27`) and take invitation and reset tokens from it (`InvitationLink.swift`, `PasswordResetLink.swift:22`).
  - The fallback pages turn the https link into a `dentory://` link (`applinks/invite/index.html:36`, `applinks/reset-password/index.html:36`).
  - Until the Apple team id replaces `TEAMID` (`applinks/.well-known/apple-app-site-association:5`), every link takes that path.
- **What could happen.** iOS does not say which app opens a scheme two apps claim. A malicious app on a member's phone could receive a token and use it with the public anon key.
- **Why accepted.** It needs a malicious app installed on the member's phone. The fallback was decided on 2026-10-19 until the domain and the team id exist. Release emails carry only https links (`Config/Release.xcconfig:7`, `_shared/invitation-email.ts:17-20`).
- **Open items.** The team id (build state, item 2), and keeping `dentory://reset-password` off the prod project's redirect URLs. Once universal links work, the custom scheme can be limited to Debug builds.

### F11 · CI actions pinned to tags (Low, accepted)

- **Where.**
  - Third-party actions: `.github/workflows/ci.yml:20` (`maxim-lobanov/setup-xcode@v1`), `:45` (`supabase/setup-cli@v1`) and `:49` (`denoland/setup-deno@v2`).
  - GitHub's own actions are tag-pinned too.
- **Why accepted.** CI runs on `pull_request` only, with `contents: read` and no secrets (`ci.yml:3-7`), and nothing it builds ships. The reviewer agent reads the diff, not just the checks. Pinning to commit SHAs, kept current by Dependabot, is worth doing when the workflows next change.

### F12 · Addresses in refusal sentences (Low, accepted)

- **Where.** Two refusals put an address in their sentence, so it also lands in the Postgres error log, which only the project's members read:
  - "{address} is already on the team" (`20261019020000_invitations.sql:85, 109`);
  - "{name} started an export less than 10 minutes ago. It goes to {address}." (`20261020180000_export_csv.sql:54`).
- **Why accepted.** The admin who triggered each one already sees that address in the app, and changing the wording changes copy the app shows.

### F13 · The session survives deleting the app (Low, accepted)

- **What happens.** supabase-swift keeps the session in the Keychain (`SupabaseClientProvider.swift`), and iOS keeps Keychain items when an app is deleted. On a shared iPad, deleting and reinstalling the app restores the last member's session.
- **Why accepted.** Sign out removes the session and clears the device (`DeviceSignOut.swift:18-28`, `AuthService.swift:131-137`), and a removed member is signed out on the next check (MS-138).

## The ticket's checklist

| Item | Result | Evidence |
|---|---|---|
| RLS on every table | Yes, all 28 tables in `public` (27 plus `invitation_sends`); the 3 views are `security_invoker` | `46_security_invariants_test.sql` fails CI when a table in a schema the API serves, or a table the API roles hold a right on in any schema they can use, has no row level security, or when a view they can read does not run as the caller. Earlier, `01_schema_test.sql` listed only the first 21 tables. |
| No service-role key or other secret in the app bundle or repo | None | Info.plist carries only the URL, the anon key, the reset URL, the Sentry DSN and PostHog's project token and host (`Dentory/Resources/Info.plist:5-16`), all public by design. Release values come from the git-ignored `Config/Secrets.xcconfig` (`.gitignore`). The only key in the history is Supabase's well-known local anon key in `Config/Debug.xcconfig:10` (issuer `supabase-demo`, signed with the documented local secret). 299 commits on all refs were searched for Stripe, Anthropic, Resend, PostHog personal, Supabase secret, GitHub, AWS, Slack and Sentry tokens, private keys and JWTs; no value was printed. |
| Storage policies | Clinic-scoped, admin-only writes, private buckets | `invoices`: admin read, insert, update and delete in the clinic's folder; insert and update only as `page-N.jpg` or `page-1.pdf`, at most 20 MB, while the clinic may write; a received invoice's pages cannot be deleted or replaced (`20261021070000_invoice_reading.sql:91-114`, `20261021100000_invoice_confirm.sql:451-478`). `logos`: members read their clinic's; admins write while the clinic may write (`20261016130000_access.sql:302-310`, `20261021000000_read_only_access.sql:35-49`). `exports`: no policy at all, so service role only, reached through 7-day signed links. `46_…` checks that no bucket is public and no Storage policy admits anon. |
| Stripe webhook signature | Checked before anything is read | `stripe_webhook/index.ts:41-45` verifies the raw body. `_shared/stripe.ts:63-86` checks the v1 HMAC-SHA256 of `t.payload` in constant time, refuses a timestamp more than 300 s away, and refuses a missing header or secret. Events are read back from Stripe rather than trusted (`supabase/README.md`, Stripe). |
| Invitation token hashing and expiry | 32 random bytes, only the SHA-256 stored, 7 days, single use | `20261019020000_invitations.sql:88-96` (random token, stored hash), `:119-149` (lookup by hash, length 20-200, not expired), `:240-246` (accept clears the hash). `team_remove` clears it on revoke (`20261021000000_read_only_access.sql:25-27`). The raw token travels only in the email, never back to the app (`invite_member/index.ts:56-61`). |
| Rate limit on invite | Added (F6) | `20261021130000_security_review.sql`, `47_security_review_test.sql` |
| Rate limit on export | One export per clinic every 10 minutes, serialised | `20261020180000_export_csv.sql:36-57` (advisory lock per clinic, the refusal naming whose export it was); the function is service role only and checks the caller is an admin of the clinic. |
| Rate limit on password reset | Supabase Auth's | Locally `max_frequency` and `email_sent` (`config.toml:205, 236`). On the hosted projects, the dashboard's email rate limits and the per-address interval (open items). The app's Reset password sends through Supabase Auth only. |
| No patient or appointment fields | None | No table, column, Swift model, analytics property or function field carries patient or appointment data. A search for patient, appointment, birth date, diagnosis and health card finds only the product "Patient bib" and the PRD's cancel-note placeholder ("e.g. Logged by mistake, patient cancelled", PRD §6.3). The invoice reader is told to leave personal data out (`extract_invoice/reading.ts:135-136`). |
| No PII in logs | Yes, with F3 fixed and F12 accepted | The app has no `print`, `NSLog`, `os_log` or `Logger`. Sentry has `sendDefaultPii` off, no screenshots, no view hierarchy and, with F7, no network breadcrumbs. The Edge Functions log ids, counts, timings, error codes and, for `send_push` without APNs keys, a push's title and body (clinic and product names). `extract_invoice` never logs invoice contents (`index.ts:92-93`). |
| No PII in analytics | Yes | Events are Appendix B ids with counts, yes or no, and words from closed lists (`Dentory/Core/Analytics/AnalyticsEvent.swift`). `AnalyticsEventTests.noPayloadCarriesFreeText` fails the build otherwise. `identify` sends the user's UUID, role and clinic UUID (`PostHogAnalytics.swift:47-61`). Autocapture, screen views, replay, surveys and GeoIP are off (`:26-45`). As `docs/handoff/analytics.md` says. |
| Edge Functions' auth checks | Each function checks its caller | `invite_member`, `export_csv` and `extract_invoice`: the gateway verifies the JWT, then `caller()` (`_shared/supabase.ts:33-43`), and the SQL function checks the caller is an admin of the clinic or invoice. `billing_checkout` and `billing_portal` (`_shared/billing.ts:26`), `send_push` (`index.ts:25`) and `send_digest` (`index.ts:24`): the bearer must be the service role key, compared in constant time (`_shared/supabase.ts:20-25`, `_shared/http.ts:58-63`). `stripe_webhook`: the Stripe signature. `accept_invitation`: the invitation token, which F1 makes trustworthy. `health`: answers `{ ok: true }` only. |
| `extract_invoice` replay seam | Never on a hosted project | `modelCallFor` (`extract_invoice/replay.ts:33-41`) replays only without `ANTHROPIC_API_KEY`, and only when `SUPABASE_URL`'s host is the local gateway `kong` (`isLocalStack`, now `_shared/environment.ts`). Neither comes from the request, and Supabase keeps `SUPABASE_` names to itself. `replay_test.ts` holds the 11 cases. |
| Security definer functions: `search_path` and grants | All on an empty search path; each callable one checks its caller | All 77 security definer functions in `public` and `engine` set `search_path = ''` and name their objects with their schema; `46_…` fails CI otherwise. Of the 35 that `authenticated` may call (before MS-146's `invoice_file_delete`, which checks an admin too), 26 check membership or the admin role of the clinic they touch (the `stock_*`, `bottle_*`, `batch_upsert` and `undo_action` functions through `engine.assert_member`, the invoice lines through `engine.invoice_line_for_review`); 7 work on the caller alone, through `auth.uid()` (`clinic_create`, `membership_state`, `push_token_register`, `current_clinic_ids`, `current_role_in`, `is_member`, `is_admin`); and 2 need neither: `clinic_can_write`, a yes or no about a clinic id, and `invitation_lookup`, which needs the token. The service-role ones (invitations, billing, push, digest, export, reading) are revoked from public, anon and authenticated. The `engine` schema is out of reach of the API roles, and so is Vault, which holds the service role key for the cron jobs (`46_…`). Supabase's own schemas (`net`, `realtime`, `supabase_functions`, `extensions`) give the API roles rights on some tables and views without RLS. The Data API serves only `public` and `graphql_public`, so no request reaches them, and the platform keeps them. |

## Open items for Grigor

Settings no repository change can make, on staging now and on prod when it exists:

1. **Auth settings** (dashboard, Authentication):
   - minimum password length 8, as the app asks;
   - "Secure password change" on, then try Forgot password once, since the reset session must still save the new password;
   - "Prevent use of leaked passwords" if the plan offers it;
   - the email rate limits and the minimum interval per address at Supabase's defaults or stricter (the local stack's 1 second is for tests only).
2. **Redirect URLs on prod:** only `https://app.dentory.ca/reset-password`. `dentory://reset-password` belongs on staging only, and only while a Debug build points at it (`supabase/README.md`, Password reset email).
3. **`RESEND_API_KEY`** on each hosted project before real invitations go out (build state, item 4). Without it nothing is sent, and the log now says only how many emails went unsent.
4. **The Apple team id** in `applinks/.well-known/apple-app-site-association` and the static host for `applinks/` (build state, items 2 and 4), so invitation and reset links open the app without the `dentory://` fallback (F10).
5. **After this PR merges, on staging:**
   - `supabase db push`;
   - deploy again every function this PR touches: `invite_member`, `export_csv`, `extract_invoice`, `stripe_webhook --no-verify-jwt` and `send_digest --no-verify-jwt`.

   MS-146's `20261021120000_invoice_file_delete.sql` merged first and sorts before this PR's `20261021130000`, so staging takes both with a plain `supabase db push`.

## Not covered

- The hosted projects themselves: their dashboard settings, the API keys in use, and the network restrictions.
- Supabase's own services and the third-party SDKs' code, beyond the options the app sets.
- The App Store binary, and the marketing site's future sign-up form endpoint (`site/index.html` still posts to a placeholder).
- Load testing, and denial of service beyond F2's time zone case, which the skill excludes.
