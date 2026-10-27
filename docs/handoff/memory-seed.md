# Memory seed for the new Dentory project

Give this file to Claude in the first message of the new project and ask it to save it to project memory. Facts are true as of 2026-10-16 15:30 UTC; the dated items in `build-state.md` move on from there.

## Project
- Dentory: dental inventory SaaS MVP for small clinics, native iOS (iPhone and iPad, Swift 6, SwiftUI, iOS 17+) on Supabase. Covers catalog, invoice receiving with AI reading, lots and expiry, procedure-based deduction, multi-use products (bottles, syringes, kits), low-stock and expiry alerts, a To buy list, stock counts, Admin and Staff roles, and a Home screen that says what needs attention. Goal: usable by a pilot clinic, then sellable.
- Owner: Grigor (GitHub `grigorhello`). Repository https://github.com/grigorhello/Dentory. Default branch is `claude/project-thread-ocu7tf` (the repo was empty when Claude first pushed); renaming it to `main` is Grigor's to do in GitHub settings. Branch protection is not set.
- The previous Claude project (private) handed over through `docs/handoff/` in the repo. Its shared folder `/mnt/project-files/` held the plan files (`medisave-plan-v2/`) and the uploaded PRD v1.0 PDF, design export zip and board PDF; the repo has everything that matters from them under `design/` and `docs/handoff/ticket-sources/`.

## Grigor's working preferences
- Wants Claude to act as a senior product owner and use its own judgment; he confirms or changes decisions afterwards. He gave the go-ahead for MS-100's decisions on 2026-10-15 without changes.
- Rule from 2026-10-16: after a merge, the next ticket in build order starts right away, without asking him; since 2026-10-27 it starts in a new thread that the coordinator opens. Ask only for what truly needs him (a decision, a password typed in his terminal, a setting on his side).
- He expects Claude to take every step it is permitted to take. When a thread asked him to press Merge himself on 2026-10-15 he pushed back ("why you can not do this?") and added permission rules on the Mac so Claude merges itself.
- He answers within minutes and asks "what are you doing now?" when a thread goes quiet: post a status refresh before any long wait.
- He follows progress on the Notion board, not GitHub Projects.
- Models (2026-10-23): Opus 5.5 builds, Sonnet 5.5 reviews, Fable 5.1 only for product decisions or a ticket too hard for Opus (was Fable 5.1 for all implementation from 2026-10-15 22:37 UTC).
- Marketing and sales for Dentory run in the same project as separate threads (said 2026-10-16 01:40 UTC).
- One project thread per ticket or fix (said 2026-10-27 03:06 UTC, to stop one long thread burning tokens): a ticket's thread resolves after its merge and the build-state update, and the next ticket starts in a new thread from `docs/handoff/build-state.md`'s "Next".

## Where things are
- Tickets: 58 tickets MS-100 to MS-157, 185 points, milestones M0 Foundations, M1 Internal Alpha, M2 Clinic Pilot, M3 Commercial Beta, M4 V1 Launch. GitHub issues #71 to #125 and #143 to #145 (MS-100..MS-152 = issue number MS minus 29; MS-153 = #124; MS-154 = #125, MS-155 to MS-157 = #143 to #145). Each issue starts with its build step, blockers and the tickets it unblocks, embeds its design frames, element ids and acceptance criteria. Labels type:/area:/priority:, milestones 1 to 5.
- Notion: board "Dentory · Product board" https://app.notion.com/p/3ee7cd9e132081b4bae8ce133881df72, database "Dentory tickets" (collection id 8819f245-33cd-4810-8e47-1d5f10d983b4), one card per issue with a link to it, Status columns Backlog, Needs design, Design review, To do, In progress, PR review, Feature QA, Done; views Board, By milestone, Design queue, table, Progress chart, Up next; Order field = build step. Card page ids per ticket: `docs/handoff/ticket-sources/notion_ids.txt`. The Board view hides empty groups; only Grigor can change that view setting.
- Design: Claude Design project "Mobile app design for Dentory" (board + PRD v1.1 + prototype), export in the repo under `design/` (38 frames f01 to f38, readable `PRD-v1.1.md`, prototype and design system sources under `design/project/`). Share links need Grigor's login, so threads read the repo copy. Design system: https://claude.ai/design/p/1666cb0d-4269-4a87-8f99-be4e150e5326?via=share; board and PRD: https://claude.ai/design/p/6fdc5e6e-2ed6-4ec3-b6ca-b46fe84fa323?file=Dentory+PRD+v1.1.dc.html&via=share.
- Repo process files: `CLAUDE.md`, `.claude/skills/dentory-ios/SKILL.md` (plus vendored MIT skills swiftui-pro and swift-concurrency), `.claude/agents/ticket-builder.md` and `.claude/agents/pr-reviewer.md`, `docs/BUILD-ORDER.md`, `.github/workflows/ci.yml` (iOS job on macOS: project, lint, build, test with warnings as errors; database job on Ubuntu: migrations, seed, pgTAP, Deno check).

## Grigor's Mac and Remote Control
- Device "MacBookPro", folder `/Users/grigorgrigoryan/Documents/Personal/Dentory` (MediSave until 2026-10-18), repo cloned there, Xcode, Docker Desktop and the Supabase CLI installed. Implementation threads run there through Remote Control; a Remote Control session that goes idle is parked and restarts on the next message with the current settings.
- Active GitHub CLI account on the Mac is `grigorhello` since 2026-10-15 22:25 UTC (`gh auth switch -u grigorhello`); plain `gh` commands act as him. PRs opened there come from his own account, so his review cannot be requested; the PR is assigned to him instead. Claude must not switch gh accounts itself (the Mac refuses it as a way around the merge rule).
- Permission rules on the Mac (added 2026-10-15): allow `gh pr merge`, `git checkout`, writes under `.claude/agents`, edits to `CLAUDE.md` and `.claude/skills`. They live in the Claude Code settings on the Mac, not in the repo.
- The Remote Control session uses Grigor's own usage limit; on 2026-10-16 it paused twice with "I've hit my usage limit" and resumed when he wrote "try again".
- The session can open a terminal tab in the thread for commands Grigor must type himself (`supabase login`, the database password for `supabase db push`).

## Supabase
- Hosted project "Dentory" (region us-east-2, Postgres 17) is the staging project for the pilot; project ref `umauofcfackicgvscefa` (the ref is part of the public API URL, not a secret; the anon key and database password are). A separate prod project is created before TestFlight (MS-152).
- The repo was linked to it on 2026-10-16 02:11 UTC. After a database ticket merges, `supabase db push` in a terminal tab sends the migrations; Grigor types the database password. As of 2026-10-16 15:30 UTC the three merged migrations (schema, access, stock engine) are not pushed yet; the thread is waiting for Grigor to say "push now".
- Secrets: the app reads SUPABASE_URL and SUPABASE_ANON_KEY from the git-ignored `Config/Secrets.xcconfig` (Release builds); `Config/Secrets.example.xcconfig` is the template; Debug builds talk to the local stack (`make db-start`), which needs no secrets.

## Build state (summary; details in build-state.md)
- Merged: MS-100 (decisions), MS-101 (#126), reviewer agent (#127), MS-102 (#128), MS-153 (#129), MS-104 (#130), MS-105 (#131), MS-106 (#132). In progress on 2026-10-16 15:23 UTC: MS-107 (product status, attention counts and values). Next in order: MS-154, MS-103, MS-108, MS-109, then M1 from MS-110.
- Open items for Grigor: say "push now" for the hosted database; the bundle id is `ca.dentory.app` (confirmed 2026-10-17) and the Apple Developer team; rename the default branch to `main`; the domain is dentory.ca (D12), with DNS and the universal links landing with MS-112 and MS-157.
