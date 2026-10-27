# Monitoring

What reaches Sentry from the app and from the Edge Functions (MS-108, MS-150), the alert rules to create, where the
DSNs go, and what only Supabase's own logs show. Nothing is sent without a DSN: Debug builds and the local stack stay
silent unless one is set on purpose.

## What is sent

**The app** (Sentry Cocoa, `Dentory/Core/Support/SentryErrorReporter.swift`):

- Crash reports, with the device model, iOS version and app version.
- Sessions, which give the crash-free session rate (Release Health). On by default; `SentryErrorReporter` keeps it on.
- One transaction for every call through `SupabaseRPCClient`: the writes that go through the write queue (every stock
  change, such as `stock_procedure_start`, `stock_count_apply`, `stock_receive`, `bottle_open`, and the other functions
  `WriteCoordinator` sends), each sent when it reaches the server, a queued one when it is replayed. The transaction is
  named after the function, its operation is `rpc`, its duration is the call's round trip from the phone, and it
  ends `ok` or with a failed status; its `kind` tag says how it ended: `ok`, `network` (the phone was offline),
  `validation` (a refusal in the app's words, such as out of stock), `read_only`, `forbidden`, `not_found` or
  `unknown` (anything else: a server error, a lost lock, an answer that does not decode). Every call is kept
  (`tracesSampleRate = 1.0`); lower it there if the Sentry plan's span quota runs out.
- A breadcrumb for each failed write (function and kind), which rides with the next crash report.

Nothing else: no screen, tap, app start or network request is traced by Sentry on its own, no Sentry header goes with
the requests to Supabase, no screenshot or view hierarchy, no network breadcrumbs (MS-151), and never a parameter, an
answer, a name, an email or anything typed. Reads (the lists) are not timed; `make perf-report` measures them on the
database (`docs/runbooks/performance.md`).

**The Edge Functions** (`supabase/functions/_shared/sentry.ts`), one event each, posted to Sentry's envelope endpoint
with `fetch` (no SDK):

| What | `kind` | Other tags |
|---|---|---|
| A function answered 500 because of an unexpected error | `unexpected` | `function`, `project` |
| A function answered 5xx on purpose (Stripe unreachable, billing not set up, a database refusal it did not expect) | the error's code: `billing_failed`, `billing_unavailable`, `unknown` | `function`, `project` |
| `extract_invoice` gave up on a reading at its 60-second limit | `timeout` | `detail`, `pages` |
| `extract_invoice` failed a reading on an error (a page that would not download, the Claude API refusing or unreachable, the result not saved) | `error` | `detail`, `pages`, `status` (an HTTP status) |
| `export_csv` failed to build, store or send an export | `export_failed` | |

An event carries the error's class and its stack frames, never its message: a message can quote an invoice, an email
address or a database row. `detail` is the function's own closed sentence ("page 2 could not be downloaded", "the call
failed (APIError 529)"). `project` is the Supabase project ref, which tells staging from prod. Events of one function
and kind group into one Sentry issue. A reading that failed because the pages could not be read, or that the model
declined, is the photo's doing and is not sent; it shows on the invoice and in the function's log.

## Setting it up (Grigor, once)

1. **Sentry projects.** Two projects in the Sentry organization: `dentory-ios` (platform Apple iOS) for the app and
   `dentory-functions` (platform Deno, or JavaScript) for the Edge Functions, so the functions' events never count in
   the app's crash-free rate. In each project's Settings › Security & Privacy, turn on Prevent Storing of IP Addresses
   and keep the Data Scrubber on.
2. **The app's DSN** (`dentory-ios`, Settings › Client Keys (DSN)): in the git-ignored `Config/Secrets.xcconfig`, which
   Release and TestFlight builds read, as `SENTRY_DSN = https:/$()/<key>@<org>.ingest.us.sentry.io/<project>` (xcconfig
   reads `//` as a comment, hence `$()`). To try it from a Debug build, the same line in `Config/Secrets.debug.xcconfig`;
   Debug events carry the environment `debug`, so filter on `production` in the alerts. Never in the repository, a chat
   or a memory.
3. **The functions' DSN** (`dentory-functions`): on each hosted project, `supabase secrets set SENTRY_DSN=https://<key>@<org>.ingest.us.sentry.io/<project> --project-ref <ref>`,
   then deploy the functions again (this ticket changed every one): `supabase functions deploy invite_member`,
   `export_csv`, `extract_invoice`, `billing_checkout`, `billing_portal`, `send_push`, `stripe_webhook --no-verify-jwt`,
   `accept_invitation --no-verify-jwt` and `send_digest --no-verify-jwt`. The secret's value is never echoed or pasted
   anywhere else; without it the functions send nothing.
4. **Check it.** A Debug build with the DSN: make a stock change (open a bottle) and find the `bottle_open` transaction
   under Performance (environment `debug`) within a minute. The functions show their first event when one happens.

## Alert rules (Grigor, in Sentry)

Create each under Alerts › Create Alert, with Grigor's email (or the team's) as the action. Low volume makes rates
jumpy: one failed call in an hour of a single clinic is a high rate, so the windows below are long; shorten them as the
number of clinics grows.

1. **Crash-free sessions under 99.5%.** Type: Crash Free Session Rate (Sessions). Project `dentory-ios`, environment
   `production`. Critical when below 99.5% over 1 day; warning below 99.8% if wanted. Name: "Crash-free sessions under
   99.5%".
2. **RPC error rate.** Type: Failure Rate (Performance). Project `dentory-ios`, environment `production`. Filter
   `transaction.op:rpc !kind:network !kind:validation !kind:read_only`, so an offline phone (whose write is queued and
   replayed) and the refusals a clinic is meant to see (out of stock, read-only mode) do not count. Critical above 2%
   over 1 day. Name: "RPC error rate above 2%". To see which function fails: Performance, filter `transaction.op:rpc`,
   group by transaction, column failure rate.
3. **Start procedure over 1 s at p95.** Type: Transaction Duration (Performance), function p95. Project `dentory-ios`,
   environment `production`, filter `transaction:stock_procedure_start kind:ok`. Critical above 1000 ms over 1 day.
4. **Apply count over 1 s at p95.** The same with `transaction:stock_count_apply kind:ok`.
5. **Edge Function errors.** Type: Issues. Project `dentory-functions`. When a new issue is created, or when an issue
   is seen more than 3 times in one hour (it regresses or repeats). Name: "Edge Function error".
6. **Edge Function timeouts.** Type: Issues. Project `dentory-functions`. When an issue is seen more than 2 times in one
   hour, filtered on the tag `kind` equals `timeout` (the event's tags match). Name: "Invoice readings timing out".

## What only Supabase shows

Sentry hears only what a function or the app lives to report. Look in the dashboard of the hosted project, weekly
during the pilot and at once when a clinic reports something:

- **A function the platform stopped** at its wall-clock, CPU or memory limit, or one that failed to boot after a
  deploy, cannot report itself: Edge Functions › the function › Logs and Invocations show the shutdown and its reason.
  `extract_invoice` gives up at 60 s on its own, well inside the platform's limit, and reports that; the minutely
  `engine.invoice_reading_timeout` job fails any reading stopped before it could.
- **Failures a function logs and retries** without failing the call: an email a digest could not send
  (`send_digest`), a device APNs refused (`send_push`), an export link email that did not go out. Edge Functions ›
  Logs, search `error`.
- **The scheduled jobs** (the nightly status refresh at 07:00 UTC, push every minute, the hourly digest, the reading
  timeout): SQL editor,
  `select j.jobname, d.status, d.return_message, d.start_time from cron.job_run_details d join cron.job j using (jobid) where d.status <> 'succeeded' order by d.start_time desc limit 20;`
  and, for the calls the jobs make to the functions, `select status_code, count(*) from net._http_response where created > now() - interval '1 day' group by 1;`.
- **The database itself:** Reports and Query Performance for slow queries, connections and disk; a query that runs into
  the statement timeout reaches the app as a failed call (`kind:unknown`) without saying why.
- **Auth and Storage:** sign-in failures and rate limits (Authentication › Logs), uploads refused by a bucket policy
  (Storage › Logs).
