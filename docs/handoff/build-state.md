# Build state

As of 2026-10-16 15:30 UTC. Before acting on this file, confirm the live state: open and merged PRs on GitHub, issue state, the Notion board. This file lags reality by design; GitHub does not.

## Merged (default branch `claude/project-thread-ocu7tf`)

| Step | Ticket | PR | Merged (UTC) | What it delivers |
|---|---|---|---|---|
| 1 | MS-100 · Build decisions (#71) | none, decision ticket | accepted 2026-10-15 02:54 | Stack and the answers to the PRD gaps; Grigor accepted them unchanged. Issue stays open as the decision record until he closes it. |
| 2 | MS-101 · iOS project (#72) | [#126](https://github.com/grigorhello/MediSave/pull/126) | 2026-10-15 22:26 | XcodeGen project, Swift 6 strict concurrency, four placeholder tabs on iPhone and iPad, SwiftLint, Makefile, CI, unit and UI test targets. |
| – | Reviewer agent | [#127](https://github.com/grigorhello/MediSave/pull/127) | 2026-10-15 22:35 | `.claude/agents/pr-reviewer.md` and the review loop in `CLAUDE.md`. |
| 3 | MS-102 · Design system (#73) | [#128](https://github.com/grigorhello/MediSave/pull/128) | 2026-10-16 00:55 | `Core/DesignSystem` tokens and components; hidden component catalog in Debug builds (long-press the "Home" text on the Home tab). |
| 4 | MS-153 · Supabase local and CI (#124) | [#129](https://github.com/grigorhello/MediSave/pull/129) | 2026-10-16 01:46 | Local stack in Docker, migrations and seed wiring, first pgTAP test, health Edge Function, database CI job. |
| 5 | MS-104 · Database schema (#75) | [#130](https://github.com/grigorhello/MediSave/pull/130) | 2026-10-16 03:39 | 13 enums, 21 tables, append-only ledger, archive-only products, clinic-locked references, `product_stock` view. |
| 6 | MS-105 · Clinic isolation and permissions (#76) | [#131](https://github.com/grigorhello/MediSave/pull/131) | 2026-10-16 13:41 | RLS on every table, Staff refused on admin-only actions, a clinic always keeps an active Admin, read-only after an ended trial, Admins cannot touch subscription columns. |
| 7 | MS-106 · Stock transaction engine (#77) | [#132](https://github.com/grigorhello/MediSave/pull/132) | 2026-10-16 15:22 | Eleven RPC functions as the only way stock moves, soonest-expiring batch first, negatives on the undated batch, alerts and To buy refresh, undo within 10 seconds, idempotency keys; 290 SQL assertions in total. |

Migrations on the default branch: `20261016021500_schema.sql`, `20261016130000_access.sql`, `20261016150000_stock_engine.sql`.

## In progress

- **MS-107 · Compute product status, attention counts and values (#78)**, build step 8, started 2026-10-16 15:23 UTC in the build thread on Grigor's Mac. No PR yet at 15:30 UTC. If a PR for it exists when you read this, continue from the review loop; if it is merged, go to the next step.

## Next, in build order

| Step | Ticket | Blocked by |
|---|---|---|
| 9 | MS-154 · App core: dependencies, data layer and session (#125) | MS-101, MS-153 (both merged) |
| 10 | MS-103 · App shell: tabs, pushed screens, sheets and toasts (#74) | MS-102, MS-154 |
| 11 | MS-108 · Errors, offline writes and double taps (#79) | MS-106, MS-154, MS-103 |
| 12 | MS-109 · Seed a demo clinic that matches the design (#80) | MS-106 |
| 13 | MS-110 · Sign in (#81), first M1 ticket | MS-105, MS-103 |

Then M1 continues MS-111, MS-112, MS-114, MS-115, MS-116, MS-117, MS-118, MS-119, MS-120, MS-121, MS-122, MS-123, MS-124, MS-113, MS-125; M2 from step 29 (MS-126); M3 from step 40 (MS-137); M4 from step 51 (MS-151) to step 55 (MS-152, TestFlight and App Store). The full table is `docs/BUILD-ORDER.md`.

## Notion board

Cards for MS-101, MS-102, MS-153, MS-104, MS-105 and MS-106 are in Feature QA for Grigor to try. MS-107 is in In progress. MS-100 is Done. Everything else is To do.

## Open items for Grigor

1. **Hosted database.** None of the three migrations is on the hosted staging project yet. Say "push now" in the build thread; it opens a terminal tab for `supabase db push`, where he types the database password. The thread proposed batching the push and he has not answered yet.
2. **Bundle id and team.** The app uses the placeholder bundle id `com.medisave.app` and no Apple Developer team; both are needed before a device build or TestFlight (MS-152).
3. **Default branch.** Rename `claude/project-thread-ocu7tf` to `main` in GitHub settings (asked 2026-10-15 03:15 UTC). After the rename, update the base branch in local checkouts and in `docs/handoff`.
4. **Production domain** for invitation and password links (MS-100 D12). Until then the Supabase project URL is used for testing.
5. **Try the merged tickets** in Feature QA and move the cards to Done.

## Known issues

- On iPad with iOS 18 the placeholder tabs sit at the top of the screen; MS-103 replaces the placeholder tab bar.
- The reviewer agent needs `gh` to act as `grigorhello` on the Mac; it stops and reports if another account is active.
- The Remote Control session draws on Grigor's own usage limit and may pause with "I've hit my usage limit"; "try again" in the thread resumes it after the reset.

## How to re-derive this file

```
gh pr list -R grigorhello/MediSave --state merged --limit 50
gh issue list -R grigorhello/MediSave --state open --limit 60 --json number,title
ls supabase/migrations
```

Then compare with `docs/BUILD-ORDER.md` and the Notion board.
