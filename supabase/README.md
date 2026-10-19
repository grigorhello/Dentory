# Database and functions

Supabase project files: `config.toml` (local stack), `migrations/` (one timestamped SQL file per change, applied in order), `seed.sql` (runs after the migrations on every reset; empty for now), `seed-demo.sql` (the demo clinic from the design, MS-109), `functions/` (Deno Edge Functions, one folder per function, shared code under `_shared/`), `tests/database/` (pgTAP tests, one file per table, policy or RPC).

Commands are in the root `Makefile` (`make db-start db-reset db-test seed-demo`; `make db-reset seed-demo` gives a fresh demo clinic; `make functions-check` type-checks the functions). Linking and pushing to the hosted projects is described in the root `README.md`.

## Edge Functions

| Function | Called by | What it does |
|---|---|---|
| `health` | nobody | `GET` answers `{ "ok": true }` so the stack and the Deno toolchain can be checked. |
| `invite_member` | the app, as a signed-in admin | `POST { clinic_id, email, role?, full_name? }`: records the invited membership with a fresh 7-day token through `invitation_create` (only the SHA-256 of the token is stored) and emails the invitee the link `https://app.dentory.ca/invite?token=…`. Calling it again for the same address resends with a new token; the old link stops working (MS-112). |
| `accept_invitation` | the Join screen, before the invitee has an account (`verify_jwt = false`) | `POST { token, full_name, password }`: reads the invitation (`invitation_lookup`), creates the account confirmed (or, after `invitation_check` says the account may join, sets the password of the account that already has the address) and makes the membership active (`invitation_accept`). A refusal (another clinic, another address, a seat already taken) answers 409 with the server's sentence and changes nothing; an expired or used link answers 410. The app then signs in with the address and password. |

Every function answers refusals as `{ "error": { "code", "message", "field"? } }` with the HTTP status the app maps in `Core/Data/AppError+Functions.swift` (`supabase/functions/_shared/http.ts`).

### Secrets and settings

The local runtime injects `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` by itself. The hosted project needs, set once with `supabase secrets set NAME=value` (never in the repo or in a chat):

| Secret | Used by | Value |
|---|---|---|
| `RESEND_API_KEY` | `invite_member` | A Resend API key for the `dentory.ca` sending domain (Resend, API keys). Without it the function sends nothing and writes the email, link included, to its log; that is how the local stack runs. |
| `EMAIL_FROM` | `invite_member` | Optional. Defaults to `Dentory <invites@dentory.ca>`; the domain must be verified in Resend (SPF and DKIM records at the registrar). |
| `APP_LINK_BASE` | `invite_member` | Optional. Defaults to `https://app.dentory.ca`, the universal-link host (`applinks/README.md`). |

Deploy with `supabase functions deploy invite_member` and `supabase functions deploy accept_invitation --no-verify-jwt` (the setting also lives in `config.toml`).

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

- Authentication, URL Configuration, Redirect URLs: add `https://app.dentory.ca/reset-password` (and `dentory://reset-password` on staging if a Debug build points at it).
- Authentication, Emails, Reset password: subject "Reset your Dentory password", body the whole of `templates/recovery.html`. `supabase config push` would also send it, together with the rest of `config.toml`, so the dashboard is the safer way.
- The universal link needs `applinks/` served on `app.dentory.ca` with the Apple team id (`applinks/README.md`). Until that domain is live the hosted emails' links lead nowhere, the same open item as the invitation links.

