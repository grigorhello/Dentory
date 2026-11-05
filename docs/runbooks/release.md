# Releases

How Dentory reaches TestFlight and the App Store (MS-152, #123): what is set up once, the steps of every release,
external testers, the App Store submission and what follows it. Builds are archived and uploaded from Grigor's Mac with
xcodebuild (`make testflight`), signed through the Apple account signed into Xcode. No CI job archives or uploads, so
the Apple account and production's keys never reach GitHub (decisions log, 2026-11-02). What to type into App Store
Connect is in `docs/handoff/app-store-connect.md`; this runbook says when.

Release builds talk to the production Supabase project, `xjtmoctrodgtnsxafeps` in West US (Oregon). Debug builds
talk to the local stack, or to staging through the git-ignored `Config/Secrets.debug.xcconfig`. Production is changed
from the Mac only, never from CI, and `supabase db push` to it only on Grigor's word.

## Once, before the first upload

### The production project (Grigor, in the Supabase dashboard)

1. **The project.** `Dentory` in Grigor's organization, created on 2026-11-04 in West US (Oregon), `us-west-2`: Grigor
   kept it there rather than recreate it in Canada (Central) (decisions log, 2026-11-05 01:38), and `site/privacy.html`
   and `docs/handoff/product-knowledge.md` name that region. Staging stays in US east (Ohio) with test data only. The
   database password stays in the password manager. The organization is on Pro, and production gets Small compute and
   point-in-time recovery (`docs/runbooks/restore.md`, "Turning them on").
2. **Its ref**, `xjtmoctrodgtnsxafeps`, is public, part of the API URL `https://xjtmoctrodgtnsxafeps.supabase.co`,
   and is the Makefile's `PRODUCTION_REF`: `make archive` refuses any other project's URL or key.
3. **The database.** From a fresh clone of the default branch ("Every release", step 1), so the Mac's own checkout
   stays linked to staging: `supabase link --project-ref xjtmoctrodgtnsxafeps` (it asks for the database password),
   then, on Grigor's word, `supabase db push`. It applies every migration in order, the private buckets and the four
   scheduled jobs included; `supabase migration list` then shows the same migrations on both sides.
4. **The Edge Functions.** `supabase functions deploy --project-ref xjtmoctrodgtnsxafeps` deploys all ten, each with
   its setting from `supabase/config.toml`, which turns JWT verification off for the four that check their callers
   themselves: `accept_invitation`, `send_push`, `send_digest` and `stripe_webhook`. The dashboard's Edge Functions
   page then lists ten, those four without JWT verification.
5. **The function secrets**, typed in the terminal and never pasted anywhere else:
   `supabase secrets set --project-ref xjtmoctrodgtnsxafeps NAME=value …` for the rows of `supabase/README.md`'s
   table ("Secrets and settings"), with production's values:
   - `RESEND_API_KEY`, for the `dentory.ca` sending domain;
   - `ANTHROPIC_API_KEY`, from a Claude Console workspace with a spend limit;
   - Stripe's live keys: `STRIPE_SECRET_KEY` (`sk_live_…`), `STRIPE_PRICE_ID`, `STRIPE_PROMO_COUPON_ID` and
     `STRIPE_WEBHOOK_SECRET`, after the "Stripe" steps of the same file in live mode, with the webhook at
     `https://xjtmoctrodgtnsxafeps.supabase.co/functions/v1/stripe_webhook`;
   - APNs: `APNS_KEY`, `APNS_KEY_ID`, `APNS_TEAM_ID=886B9D4D6M` and `APNS_ENVIRONMENT=production`, since TestFlight and
     App Store builds register with Apple's production service;
   - `SENTRY_DSN` of the `dentory-functions` project (`docs/runbooks/monitoring.md`).

   `supabase secrets list --project-ref xjtmoctrodgtnsxafeps` shows the names that are set.
6. **Vault, for the scheduled jobs.** The database calls `send_push` each minute and `send_digest` each hour with the
   URL and key it finds in Vault (build state, item 9). In production's SQL editor,
   `select vault.create_secret('https://xjtmoctrodgtnsxafeps.supabase.co', 'project_url');` and
   `select vault.create_secret('<service role key>', 'service_role_key');` with the legacy `service_role` key (Project
   Settings › API Keys › Legacy API Keys); close the query without saving it. Without them pushes are dropped after a
   day and digests stay queued.
7. **Auth settings** (Authentication), as the security review asks (`docs/security/security-review.md`, "Open items for
   Grigor") and as `supabase/config.toml` sets the local stack:
   - Sign In / Providers › Email: Confirm email off (`enable_confirmations = false`), since sign-up goes straight on to
     creating the clinic (MS-111); minimum password length 8, the app's rule; Secure password change on, then try
     Forgot password once; Prevent use of leaked passwords on.
   - URL Configuration: Site URL `https://app.dentory.ca`; Redirect URLs `https://app.dentory.ca/reset-password` and
     nothing else (never `dentory://` on production, F10).
   - Emails: custom SMTP through Resend, and the Reset password template with the subject "Reset your Dentory password"
     and the body of `supabase/templates/recovery.html` (`supabase/README.md`, "Password reset email", MS-113).
   - Rate Limits: Supabase's defaults or stricter.

### The app's keys (Grigor, on the Mac)

The Mac's own checkout keeps production's URL and anon key in its git-ignored `Config/Secrets.xcconfig`, and every
release copies that file into its fresh clone. Write it from the Supabase CLI, so the key is never shown, in the Mac's
checkout once `PRODUCTION_REF` is merged there:

```sh
ref=xjtmoctrodgtnsxafeps
supabase projects api-keys --project-ref "$ref" -o json | python3 -c '
import json, sys
key = next(k["api_key"] for k in json.load(sys.stdin) if k["name"] == "anon")
print("SUPABASE_URL = https:/$()/" + sys.argv[1] + ".supabase.co")
print("SUPABASE_ANON_KEY = " + key)' "$ref" > Config/Secrets.xcconfig
make release-check
```

The key is the legacy `anon` key the app is built and tested with. The command writes the file afresh: add after it
the `SENTRY_DSN` of `dentory-ios` (`docs/runbooks/monitoring.md`, step 2) and, once there is one,
`POSTHOG_PROJECT_TOKEN` (build state, item 11). `make release-check` prints nothing when the file holds production's
URL and anon key and one line naming what is wrong otherwise: no `PRODUCTION_REF`, no file, another project's URL, an
empty key, or a key that is not production's anon key (another project's, or the service role key, which must never
ship in the app). It never prints the key.

### Apple (Grigor)

1. **Xcode › Settings › Accounts**: the Apple account of Dentory's team (team ID `886B9D4D6M`, individual enrollment)
   signed in. `make archive` and `make upload` sign through it: with `-allowProvisioningUpdates` Xcode creates the
   Apple Distribution certificate and the App Store profile, and turns on the app's capabilities (Associated Domains,
   Push Notifications) for the App ID `ca.dentory.app`. The first time codesign uses the new certificate's key, macOS
   may ask in a dialog on the Mac, with the login password: Always Allow. Until someone answers it, the archive waits
   at its signing step.
2. **The agreements** accepted (`app-store-connect.md`, step 0): an Apple Developer Program License Agreement waiting in
   App Store Connect or at developer.apple.com blocks every upload.
3. **The APNs key** (developer.apple.com › Keys › Apple Push Notifications service) for the secrets above (build state,
   item 9).
4. **The App Store Connect record** as `app-store-connect.md` steps 1 to 5 describe it, the internal group
   "Dentory team" with automatic distribution on included.

## Every release

Only from the default branch: the build number is its commit count at the archived commit, `git rev-list --count HEAD`
(decisions log, 2026-11-02), which only grows along that branch. Always in a fresh clone, so nothing local ships. Give
`make` the same `SPM_DIR`, `SPM_FLAGS` and `SIM_ID` as for `make test` (`docs/handoff/mac-tooling.md`) to reuse the
Mac checkout's packages.

1. **Clone.** `/usr/bin/git clone https://github.com/grigorhello/Dentory.git /tmp/dentory-release` (any new folder),
   `cd` into it and `make project`. When the commit adds a migration or changes a function, push those to production
   first, on Grigor's word (above, steps 3 and 4): a build may only call what production already has, and the builds
   already on testers' phones must keep working with it.
2. **The end-to-end flows.** `supabase stop` (the stack of whichever checkout runs it), `make db-start` in the clone,
   then `make e2e`: the seven flows on the local stack, about five minutes. All of them pass, or there is no release.
   `supabase stop` afterwards.
3. **Production's keys.** `cp ~/Documents/Personal/Dentory/Config/Secrets.xcconfig Config/`, then `make release-check`.
4. **Upload.** `make testflight`: `make release-check`, then a Release archive for any iOS device in
   `build/release/Dentory.xcarchive`, version `MARKETING_VERSION` from `project.yml` (1.1.0) and build number the
   commit count, signed automatically; then `xcodebuild -exportArchive` with `Config/ExportOptions.plist` uploads it
   to App Store Connect with its symbols (`build/release/export` keeps the logs). `make archive` and `make upload` run
   the two halves. To upload the same commit again, after a build Apple could not process:
   `make testflight BUILD_NUMBER=<count>.1`.
5. **Crash symbols for Sentry**, once Sentry is set up:
   `sentry-cli debug-files upload --org <org> --project dentory-ios build/release/Dentory.xcarchive/dSYMs`, with a
   Sentry auth token in `SENTRY_AUTH_TOKEN`, so the build's crash reports read as code. App Store Connect has its own
   copy from the upload.
6. **Processing.** App Store Connect › TestFlight lists the build as Processing, usually for 5 to 30 minutes, then Apple
   emails. Export compliance is already answered: `Info.plist` sets `ITSAppUsesNonExemptEncryption` to false, since the
   app uses only HTTPS, so no "Missing Compliance" appears. An email naming ITMS-91053 (the build calls a
   required-reason API its privacy manifest does not declare) or ITMS-91056 (a manifest Apple cannot read) means a fix
   to `Dentory/Resources/PrivacyInfo.xcprivacy` ("After a release", The privacy manifest), in a pull request, before the
   next upload. The internal group "Dentory team" has automatic distribution on and gets the build at once; its testers
   install it from the TestFlight app.
7. **Test it** on an iPhone and an iPad, against production:
   - sign up a clinic, or sign in to the review clinic (below); Home, Inventory, Procedures, To buy and Activity load;
   - start a procedure and edit its usage, count stock, receive manually, and receive a delivery from a photo of a
     real invoice, read by the Claude API in under 20 seconds;
   - invite a teammate: the email comes from `@dentory.ca` and its link opens the app once `app.dentory.ca` serves
     `applinks/`; Forgot password the same;
   - allow notifications and let a product run out: the push arrives;
   - Billing shows the trial with no payment button or link (MS-100 D18), and Export CSV's email arrives;
   - in airplane mode a change is queued, and it syncs when the phone is back online;
   - Sentry's `dentory-ios` shows the session under the `production` environment, and PostHog the events, once their
     keys are in the build.

   What is found becomes a ticket like any other; a P0 or P1 stops the release.
8. **Record it** in the table at the end.

## External testers

Waits for `https://dentory.ca/privacy` and `https://dentory.ca/support` to serve `site/privacy.html` and
`site/support.html` with their placeholders filled (GitHub Pages and the DNS, MS-161), and for #107's week of internal
use to end with no P0 or P1 left open.

1. **The review clinic on production**, the demo clinic of the App Review notes, made through the app on a TestFlight
   build, never with `supabase/seed-demo.sql`, which is for the local stack only and whose password is in this public
   repository. Sign up as admin with an address Grigor reads and a password from the password manager, a clinic named
   Smile Dental in Canada; add a few products (one multi-use, one expiring within 30 days, one under its minimum), a
   procedure and a manual receipt, so that every tab has something to show; invite a Staff teammate at a second address
   and accept the invitation from that email with a password of its own. Its trial runs 3 months from sign-up, then the
   clinic turns read-only: before a review falls past that day, extend it in production's SQL editor,
   `update clinics set trial_ends_at = now() + interval '3 months' where id = '<clinic id>';`.
2. **Test information** as `app-store-connect.md` step 5 has it, the review clinic's Admin and Staff accounts in the
   Beta App Review information.
3. **The group.** TestFlight › External Testing › "+": "Pilot clinics". Adding a build sends it to Beta App Review: the
   first build of a version, usually within a day; later builds of the same version often go straight through. Then
   add the pilot clinics' people by email.

## App Store submission

After external testing, with the same pages live and `app.dentory.ca` serving `applinks/`, so that the invitation and
password reset links open the app for the reviewers.

1. **Screenshots from the shipped build**: the released commit, in its clone, on the iPhone 16 Pro Max simulator
   (6.9-inch, 1320 × 2868 px) and the iPad Pro 13-inch (M4) simulator (2064 × 2752 px), signed in to the demo clinic of
   the local stack seeded that day (`make db-reset seed-demo`; its dates are relative to the day it runs). Set the
   status bar first (`xcrun simctl status_bar <id> override --time 9:41 --batteryState charged --batteryLevel 100`)
   and take each with `xcrun simctl io <id> screenshot <name>.png`;
   `sips -g pixelWidth -g pixelHeight -g hasAlpha <name>.png` must give that size and no alpha, since Apple refuses
   transparency (`sips -s format jpeg` drops it).
   One to ten per device, in the order and with the captions of the listing (`app-store-connect.md`, step 4).
2. **The version page**, 1.1.0, as `app-store-connect.md` step 4 has it: the text, the URLs, the copyright, the build
   just tested, App Review information with the review clinic's Admin account and the notes naming the Staff one, and
   "Manually release this version".
3. **Billing.** The review risk the ticket names, linking to Stripe's hosted billing, is settled by MS-100 D18: the app
   has no purchase button or link, Billing shows the state only and the payment page reaches the clinic by email,
   which is the ticket's fallback already. Nothing is hidden for review, and the review notes say so (Guideline
   3.1.3(c), enterprise services).
4. **Add for Review**, then Submit to App Review. Review usually takes a day or two; Apple's questions arrive in App
   Store Connect under App Review. Once approved, the version waits as Pending Developer Release until Grigor releases
   it.

## After a release

- **The next version.** Once 1.1.0 is approved, App Store Connect takes no more builds of it: the next upload needs a
  higher `MARKETING_VERSION` in `project.yml` (1.1.1 for fixes, 1.2.0 for features), in a pull request like any other
  change, and the new version in App Store Connect (iOS App, "+") before it is submitted. Build numbers keep growing on
  their own.
- **The privacy manifest.** `Dentory/Resources/PrivacyInfo.xcprivacy`, at the root of the app, declares no tracking,
  the data the app collects, row for row the App Privacy label of `app-store-connect.md` step 3 (a change to one is a
  change to the other), and every required-reason API that `Dentory.app/Dentory` calls, the code of the packages linked
  into it included, since Sentry, PostHog and supabase-swift are static: user defaults, file timestamps and system boot
  time, each with the reason the decisions log gives (2026-11-05 02:52). A pull request that calls a new one (disk
  space, active keyboards, `UserDefaults(suiteName:)` for an App Group), uses one for another reason, or adds or
  updates a package that does, declares it there. Apple reads the binary, not what runs, and App Store Connect does not
  accept a build that misses one (ITMS-91053). After `make archive` these print what the build calls: today
  `_stat`, `_fstat`, `NSFileCreationDate`, `NSURLCreationDateKey` and `NSURLContentModificationDateKey` (file
  timestamps), `_mach_absolute_time` and `systemUptime` (system boot time) and `NSUserDefaults` (user defaults);
  anything new they print needs its category in the manifest, with a reason that fits its use.

  ```sh
  app=build/release/Dentory.xcarchive/Products/Applications/Dentory.app/Dentory
  calls='^_(f?stat|lstat|fstatat|f?getattrlist|getattrlist(bulk|at)|f?statv?fs|mach_absolute_time)$'
  keys='NSUserDefaults|NSFile(Creation|Modification)Date|NSFileSystem|NSURL(Volume|Creation|ContentModification)'
  nm -u "$app" | grep -E "$calls|$keys"
  otool -v -s __TEXT __objc_methname "$app" | grep -E 'systemUptime|activeInputModes|initWithSuiteName'
  ```
- **Tag** the commit the App Store got: `git tag v1.1.0 <sha>` and `git push origin v1.1.0`, so the next release's
  changes read as `git log v1.1.0..`.
- **The clone** can go once the build is processed and its symbols are in Sentry; App Store Connect keeps its own.

## Record

| Date | Version | Build | Commit | `make e2e` | Uploaded by | Internal testing | External testing | App Store |
|---|---|---|---|---|---|---|---|---|
| | | | | | | | | |
