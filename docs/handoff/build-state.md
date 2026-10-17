# Build state

As of 2026-10-17 16:30 UTC. Before acting on this file, confirm the live state: open and merged PRs on GitHub, issue state, the Notion board. This file lags reality by design; GitHub does not.

## Merged (default branch `claude/project-thread-ocu7tf`)

| Step | Ticket | PR | Merged (UTC) | What it delivers |
|---|---|---|---|---|
| 1 | MS-100 · Build decisions (#71) | none, decision ticket | accepted 2026-10-15 02:54 | Stack and the answers to the PRD gaps; Grigor accepted them unchanged. Issue stays open as the decision record until he closes it. |
| 2 | MS-101 · iOS project (#72) | [#126](https://github.com/grigorhello/Dentory/pull/126) | 2026-10-15 22:26 | XcodeGen project, Swift 6 strict concurrency, four placeholder tabs on iPhone and iPad, SwiftLint, Makefile, CI, unit and UI test targets. |
| – | Reviewer agent | [#127](https://github.com/grigorhello/Dentory/pull/127) | 2026-10-15 22:35 | `.claude/agents/pr-reviewer.md` and the review loop in `CLAUDE.md`. |
| 3 | MS-102 · Design system (#73) | [#128](https://github.com/grigorhello/Dentory/pull/128) | 2026-10-16 00:55 | `Core/DesignSystem` tokens and components; hidden component catalog in Debug builds (long-press the "Home" text on the Home tab). |
| 4 | MS-153 · Supabase local and CI (#124) | [#129](https://github.com/grigorhello/Dentory/pull/129) | 2026-10-16 01:46 | Local stack in Docker, migrations and seed wiring, first pgTAP test, health Edge Function, database CI job. |
| 5 | MS-104 · Database schema (#75) | [#130](https://github.com/grigorhello/Dentory/pull/130) | 2026-10-16 03:39 | 13 enums, 21 tables, append-only ledger, archive-only products, clinic-locked references, `product_stock` view. |
| 6 | MS-105 · Clinic isolation and permissions (#76) | [#131](https://github.com/grigorhello/Dentory/pull/131) | 2026-10-16 13:41 | RLS on every table, Staff refused on admin-only actions, a clinic always keeps an active Admin, read-only after an ended trial, Admins cannot touch subscription columns. |
| 7 | MS-106 · Stock transaction engine (#77) | [#132](https://github.com/grigorhello/Dentory/pull/132) | 2026-10-16 15:22 | Eleven RPC functions as the only way stock moves, soonest-expiring batch first, negatives on the undated batch, alerts and To buy refresh, undo within 10 seconds, idempotency keys; 290 SQL assertions in total. |
| 8 | MS-107 · Product status, attention counts and values (#78) | [#134](https://github.com/grigorhello/Dentory/pull/134) | 2026-10-16 16:36 | `days_to_expiry`, `evaluate_product_status`, the `product_status` and `clinic_attention` views (Home tiles, inventory value, value at risk), nightly `refresh_all_products` via pg_cron; 324 SQL assertions in total. |
| 9 | MS-154 · App core: dependencies, data layer and session (#125) | [#135](https://github.com/grigorhello/Dentory/pull/135) | 2026-10-16 18:06 | `AppDependencies` (live and preview), `RPCCalling` with idempotency keys and `AppError` mapping, Supabase auth service and `SessionStore`, `Clock`, `NetworkMonitoring`, `ClinicFormatters`, `CalendarDay` for Postgres dates; `-uiTesting` launch argument runs the app on fakes. |
| 12 | MS-109 · Demo clinic seed (#80) | [#136](https://github.com/grigorhello/Dentory/pull/136) | 2026-10-16 19:00 | `supabase/seed-demo.sql` and `make seed-demo`: Smile Dental with the prototype's products, templates, procedures, To buy list and invoice, written through the engine RPCs. Sign in as sarah@smiledental.ca (Admin) or michael@smiledental.ca (Staff), password `smiledental`. Built out of order by a second session. |
| 10 | MS-103 · App shell (#74) | [#138](https://github.com/grigorhello/Dentory/pull/138) | 2026-10-16 19:07 | `AppRouter`, drawn `AppTabBar` (same bottom tabs on iPad), root and pushed screen containers, `PinnedPrimaryBar`, `MSSheet`/`SheetList`, `ToastCenter`, `OfflineBanner`, `ContentColumn`, `.adminOnly()`; Debug shell demo from Home and a Shell section in the catalog. |
| 11 | MS-108 · Errors, offline writes and double taps (#79) | [#140](https://github.com/grigorhello/Dentory/pull/140) | 2026-10-16 19:39 | `WriteCoordinator` (online now, queued offline, replayed in order with the same idempotency keys), `PendingWriteQueue` (survives relaunch), `ResponseCache`, `SubmitGuard` (one submission at a time), `reloadOnReturn`, Sentry Cocoa started from `SENTRY_DSN` with data-free breadcrumbs, the offline banner "You're offline. Changes will sync.". |
| 13 | MS-110 · Sign in (#81) | [#141](https://github.com/grigorhello/Dentory/pull/141) | 2026-10-17 15:06 | Sign in screen of f1 (no Google button), inline errors under the field Supabase named, show/hide password, one submission at a time, revoked-membership toast; the preview auth accepts the demo clinic's credentials for the UI flow. |
| 14 | MS-114 · Home (#85) | [#142](https://github.com/grigorhello/Dentory/pull/142) | 2026-10-17 15:32 | Home of f6/f7/f36: attention tiles (ink at 0), dark procedure card with the latest procedure, value tiles, Admin-only Receive delivery row; `clinic_attention` + latest `procedure_events` + unseen alerts, cached for offline; placeholder pushed screens for the tickets that bring them; the Supabase client now decodes snake_case rows (`SupabaseClientProvider.options`). |
| 15 | MS-155 · Rename to Dentory, code and repository (#143) | [#146](https://github.com/grigorhello/Dentory/pull/146) | 2026-10-17 15:49 | Repository `grigorhello/Dentory`; project, targets, folders `Dentory*`; bundle id `ca.dentory.app`; Makefile, lint, local Supabase (`supabase_db_Dentory`), pgTAP fixtures, skill `dentory-ios` (MS stays the design-system prefix), reviewer agent. |

Migrations on the default branch: `20261016021500_schema.sql`, `20261016130000_access.sql`, `20261016150000_stock_engine.sql`, `20261016170000_product_status.sql`.

## In progress

- **MS-156 · Rename in the docs, the design files, the ticket sources and the issues (#144)**, build step 16, started 2026-10-17 15:40 UTC in the build thread on Grigor's Mac: this file is part of its PR; the re-rendered f01 frame merged separately as [#148](https://github.com/grigorhello/Dentory/pull/148). If the MS-156 PR is merged when you read this, go to the next step.

## Next, in build order

| Step | Ticket | Blocked by |
|---|---|---|
| 17 | MS-157 · Rename the services and accounts outside the repository (#145) | MS-155 (merged); mostly Grigor's own checklist |
| 18 | MS-111 · Admin sign-up: account, clinic and team invites (#82) | MS-104, MS-110, MS-155 (all merged) |
| 19 | MS-112 · Invite teammates and accept an invitation (#83) | MS-111 |

Then M1 continues MS-115, MS-116, MS-117, MS-118, MS-119, MS-120, MS-121, MS-122, MS-123, MS-124, MS-113, MS-125; M2 from step 29 (MS-126); M3 from step 40 (MS-137); M4 from step 51 (MS-151) to step 55 (MS-152, TestFlight and App Store). The full table is `docs/BUILD-ORDER.md`.

## Notion board

Cards for MS-101, MS-102, MS-153, MS-104, MS-105, MS-106, MS-107, MS-154, MS-109, MS-103, MS-108, MS-110, MS-114 and MS-155 are in Feature QA for Grigor to try. MS-156 is in In progress. MS-100 is Done. Everything else is To do. The board is "Dentory · Product board".

## Open items for Grigor

1. **Hosted database.** None of the four migrations is on the hosted staging project yet. Say "push now" in the build thread; it opens a terminal tab for `supabase db push`, where he types the database password. The thread proposed batching the push and he has not answered yet.
2. **Apple Developer team.** The bundle id is `ca.dentory.app` (confirmed 2026-10-17); an Apple Developer team and the App Store Connect record are still needed before a device build or TestFlight (MS-152). MS-157 lists the other accounts to rename (Claude project, Supabase project name, DNS for dentory.ca).
3. **Default branch.** Rename `claude/project-thread-ocu7tf` to `main` in GitHub settings (asked 2026-10-15 03:15 UTC). After the rename, update the base branch in local checkouts and in `docs/handoff`.
4. **Production domain** is `dentory.ca` (links on `app.dentory.ca`, email from `@dentory.ca`, MS-100 D12); DNS and the universal-link setup land with MS-112 and MS-157. Until then the Supabase project URL is used for testing.
5. **Try the merged tickets** in Feature QA and move the cards to Done.

## Known issues

- The demo clinic's inventory value is about $1,616 where frame f6 shows $12,420: the prototype has no unit costs and the seed uses realistic ones, pinned so f27 reads $82 + $104. Reaching the frame's figure with the frame's quantities would need implausible prices; Grigor decides whether the number matters for demos.
- Sheets use the system scrim, not the PRD's `rgba(32,21,21,.4)`; SwiftUI does not expose the sheet scrim colour.
- The reviewer agent needs `gh` to act as `grigorhello` on the Mac; it stops and reports if another account is active.
- The Remote Control session draws on Grigor's own usage limit and may pause with "I've hit my usage limit"; "try again" in the thread resumes it after the reset.

## How to re-derive this file

```
gh pr list -R grigorhello/Dentory --state merged --limit 50
gh issue list -R grigorhello/Dentory --state open --limit 60 --json number,title
ls supabase/migrations
```

Then compare with `docs/BUILD-ORDER.md` and the Notion board.
