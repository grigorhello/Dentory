# Build state

As of 2026-10-19 17:00 UTC. Before acting on this file, confirm the live state: open and merged PRs on GitHub, issue state, the Notion board. This file lags reality by design; GitHub does not.

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
| 16 | MS-156 · Rename in the docs, the design files, the ticket sources and the issues (#144) | [#147](https://github.com/grigorhello/Dentory/pull/147) | 2026-10-17 17:19 | Docs, design files, ticket sources, issues and this handoff pack say Dentory; the re-rendered f01 frame merged as [#148](https://github.com/grigorhello/Dentory/pull/148). |
| 18 | MS-111 · Admin sign-up: account, clinic and team invites (#82) | [#149](https://github.com/grigorhello/Dentory/pull/149) | 2026-10-17 17:57 | The three sign-up steps of f2, f3, f4: Supabase sign-up, `clinic_create` (clinic, admin membership, profile, ten categories, currency from the country), invited rows at step 3, resume at the pending step after a relaunch; `membership_state()`; 32 pgTAP assertions. |
| 19 | MS-112 · Invite teammates and accept an invitation (#83) | [#150](https://github.com/grigorhello/Dentory/pull/150) | 2026-10-19 02:47 | Migration `20261019020000_invitations.sql` (`invitation_create`, `invitation_lookup`, `auth_user_id_for_email`, `invitation_accept`; `invite_members` dropped), Edge Functions `invite_member` (Resend) and `accept_invitation`, the Join screen (f5), the `dentory://` scheme and the `applinks:app.dentory.ca` entitlement, the `applinks/` static files for the domain. |
| – | MS-112 fix · Read-only address keeps the Join password field typeable | [#159](https://github.com/grigorhello/Dentory/pull/159) | 2026-10-19 08:21 | `MSReadOnlyField` for the invited address; iOS no longer covers the new-password field with its strong-password suggestion on a simulator whose software keyboard is hidden; Return moves from the name to the password. |
| 20 | MS-115 · Inventory list: browse, search and filter (#86) | [#151](https://github.com/grigorhello/Dentory/pull/151) | 2026-10-19 08:40 | `inventory_list` (12 pgTAP assertions), `Features/Inventory`, `ProductSummary`, the chips with Low including Out of stock, case- and accent-insensitive search, status-priority sort, the Admin-only +, Home's Missing expiry tile preselecting the chip, the `-tab` and `-inventoryFilter` launch hooks, `tabBarInset`. |
| 21 | MS-116 · Product detail (#87) | [#160](https://github.com/grigorhello/Dentory/pull/160) | 2026-10-19 13:04 | `product_detail` (23 pgTAP assertions; `used_in_30_days` nets edits and cancellations), `Features/ProductDetail` (quantity, expiry, bottles and history cards, Add to buy with Undo, a refused add reloads), `ProductDetail`, `TransactionType`, `PersonName`, the `.context` header style, `EqualWidthHStack`, `ClinicFormatters.shortMonth`, the trash icon. Three review rounds: the snake_case decoder reads `used_30d` as `used30D` (keys must not start a component with a digit; a decoding test on the seeded answer guards it), both roles read "Add to buy" (G2), batch rows show the month, zero-delta rows read "0". |
| 23 | MS-118 · Adjust a quantity with a reason (#89) | [#162](https://github.com/grigorhello/Dentory/pull/162) | 2026-10-19 16:38 | Built in Grigor's cloud Claude Code session (branch `claude/ecstatic-noether-scu5l7`), outside this project's threads: `AdjustmentReason`, `ProductDetailRepository.adjust` and `undoAdjustment` through `WriteCoordinator` (`stock_adjust`, `undo_action`), the `adjust` sheet under `Features/ProductDetail` (`AdjustInventoryViewModel`, `AdjustInventorySheet`), Undo from the toast, history rows reading "Undo · Damaged". |

Migrations on the default branch: `20261016021500_schema.sql`, `20261016130000_access.sql`, `20261016150000_stock_engine.sql`, `20261016170000_product_status.sql`, `20261017160000_onboarding.sql`, `20261019020000_invitations.sql`, `20261019040000_inventory_list.sql`, `20261019090000_product_detail.sql`.

## In progress

- **MS-117 · Create, edit and delete products (#88)**, build step 22, in PR review: [#161](https://github.com/grigorhello/Dentory/pull/161), opened 2026-10-19 13:43 UTC from the build thread on Grigor's Mac (checkout `/Users/grigorgrigoryan/Documents/Personal/Dentory`), branch `ms-117-product-sheets`. Three review rounds ran; every finding is fixed and pushed, and the branch carries the default branch with MS-118 merged in (conflicts in `Features/ProductDetail` resolved: Edit, Delete and Adjust sheets side by side). Under CLAUDE.md's three-round rule it waits for Grigor's word in the build thread before it is merged. This file is part of its PR. If #161 is merged when you read this, go to the next step.
- **MS-157 · Rename the services and accounts outside the repository (#145)**, build step 17, is Grigor's checklist (Claude project, Supabase display name, Apple, DNS, Claude Design); nothing in the repository is left for it.

## Next, in build order

| Step | Ticket | Blocked by |
|---|---|---|
| 24 | MS-119 · Track expiry per batch: Add expiry and Edit batch (#90) | MS-106 (merged), MS-116 (merged) |

Then M1 continues MS-120, MS-121, MS-122, MS-123, MS-124, MS-113, MS-125; M2 from step 32 (MS-126); M3 from step 43 (MS-137); M4 from step 54 (MS-151) to step 58 (MS-152, TestFlight and App Store). The full table is `docs/BUILD-ORDER.md`.

## Notion board

Cards for MS-101, MS-102, MS-153, MS-104, MS-105, MS-106, MS-107, MS-154, MS-109, MS-103, MS-108, MS-110, MS-114, MS-155, MS-156, MS-111, MS-112, MS-115, MS-116 and MS-118 are in Feature QA for Grigor to try. MS-117 is in PR review. MS-100 is Done. Everything else is To do, except the brand cards: MS-158 is in Feature QA and MS-159 to MS-162 are in Backlog (see "Brand assets" below). The board is "Dentory · Product board".

## Open items for Grigor

1. **Hosted database.** None of the nine migrations is on the hosted staging project yet, and the two Edge Functions are not deployed there (`supabase functions deploy`). Say "push now" in the build thread; it opens a terminal tab for `supabase db push`, where he types the database password. The thread proposed batching the push and he has not answered yet.
2. **Apple Developer team and App Store Connect.** The team exists and the App Store Connect record for `ca.dentory.app` was created on 2026-10-19; what goes into every screen is in `app-store-connect.md` (name, categories, 4+, free, Canada only, privacy label, version 1.1.0, TestFlight test information). For the build thread, one small PR: the Team ID in `applinks/.well-known/apple-app-site-association`, `DEVELOPMENT_TEAM` and `CODE_SIGN_STYLE: Automatic` in `project.yml`, `ITSAppUsesNonExemptEncryption` false in `Info.plist`. The demo accounts for App Review and the screenshots come with the production project and MS-152. MS-157 lists the other accounts to rename (Claude project, Supabase project name, DNS for dentory.ca).
3. **Default branch.** Rename `claude/project-thread-ocu7tf` to `main` in GitHub settings (asked 2026-10-15 03:15 UTC). After the rename, update the base branch in local checkouts and in `docs/handoff`.
4. **Production domain** is `dentory.ca` (links on `app.dentory.ca`, email from `@dentory.ca`, MS-100 D12). MS-112 built the app side; what Grigor adds, in this order: a Resend account with `dentory.ca` as a verified sending domain (Resend gives the SPF and DKIM records to add at the registrar) and its API key set with `supabase secrets set RESEND_API_KEY=…` on the hosted project; a static host for the `applinks/` folder at `https://app.dentory.ca` (its `apple-app-site-association` needs the Apple team id, so universal links only work once the Apple Developer team exists); until then the emails carry `https://app.dentory.ca/invite?token=…` links that the fallback page turns into `dentory://` links, and the simulator opens `dentory://invite?token=…` directly.
5. **Try the merged tickets** in Feature QA and move the cards to Done.
6. **Brand tickets.** MS-159 to MS-162 (#153 to #156) wait for his word on which to build and when; the landing page (MS-161) also needs the DNS records for GitHub Pages at the registrar, listed in the issue.

## Brand assets (outside the build order)

Grigor delivered the visual identity on 2026-10-19 (MS-100 D17): `design/brand/` holds the molar mark, the lockups and wordmark, the iOS icon set, the web favicons and the Android icons, with a README of rules and an inventory. The brand tickets are GitHub issues #152 to #156; their source is `docs/handoff/ticket-sources/brand/brand-assets.md` and their generator `build_brand.py` (see `engineering-process.md` section 9). They are not in `docs/BUILD-ORDER.md`; the icon is merged and the other four wait for Grigor's word.

| Ticket | State | What it delivers |
|---|---|---|
| MS-158 · App icon from the brand package (#152) | Merged as [#157](https://github.com/grigorhello/Dentory/pull/157) on 2026-10-19 06:56; card in Feature QA (home-screen check on the simulators is part of the QA, the cloud session could not capture it) | The single-size 1024 px icon with dark and tinted appearances in `Assets.xcassets/AppIcon.appiconset`, copied from `design/brand/ios/`. |
| MS-159 · Brand mark and wordmark in the app (#153) | Backlog | Vector image sets and an `MSLogo` design-system component; the lockup replaces the "Dentory" text on the sign-in screen. |
| MS-160 · Launch screen with the mark on cream (#154) | Backlog | A `UILaunchScreen` with the mark on cream instead of the generated blank screen. |
| MS-161 · Landing page dentory.ca with the brand (#155) | Backlog; Grigor said he will ask for it | Restyle of `site/` (PR #137) with the lockup, favicons, manifest and brand colours; `CNAME` and the GitHub Pages custom domain; the DNS records are his. |
| MS-162 · Brand in emails and link pages (#156) | Backlog | Shared email header and footer for the Edge Functions, Supabase Auth templates, the invite link page. |

## Known issues

- The demo clinic's inventory value is about $1,616 where frame f6 shows $12,420: the prototype has no unit costs and the seed uses realistic ones, pinned so f27 reads $82 + $104. Reaching the frame's figure with the frame's quantities would need implausible prices; Grigor decides whether the number matters for demos.
- Sheets use the system scrim, not the PRD's `rgba(32,21,21,.4)`; SwiftUI does not expose the sheet scrim colour.
- The reviewer agent needs `gh` to act as `grigorhello` on the Mac; it stops and reports if another account is active.
- The Remote Control session draws on Grigor's own usage limit and may pause with "I've hit my usage limit"; "try again" in the thread resumes it after the reset.
- `/usr/local/bin/git` on the Mac is an Intel-only Homebrew build that this Apple-silicon Mac cannot run ("bad CPU type in executable") and it comes first on the PATH: `gh` fails with it, and the Claude Desktop app's worktree sessions failed on it on 2026-10-18. Build sessions put Apple's git first (`PATH=/usr/bin:$PATH`) for `gh`; removing that git fixes it for good.

## How to re-derive this file

```
gh pr list -R grigorhello/Dentory --state merged --limit 50
gh issue list -R grigorhello/Dentory --state open --limit 60 --json number,title
ls supabase/migrations
```

Then compare with `docs/BUILD-ORDER.md` and the Notion board.
