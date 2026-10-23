# Dentory

Dental inventory app for small clinics: iPhone and iPad, two roles (Admin, Staff). Spec: `design/PRD-v1.1.md` and `design/frames/`. Process, build state and product knowledge: `docs/handoff/` (start with its README); the reasons behind the rules below are in `docs/handoff/engineering-process.md`.

## Tickets
- Each ticket runs in a fresh context: the build thread starts a `ticket-builder` agent (`.claude/agents/ticket-builder.md`) per ticket or fix and keeps only the coordination itself.
- Follow the `dentory-ios` skill for every ticket; `swiftui-pro` reviews SwiftUI code, `swift-concurrency` fixes concurrency errors.
- Tickets are GitHub issues `MS-1NN · …`, built in [`docs/BUILD-ORDER.md`](docs/BUILD-ORDER.md) order. Never start one while a blocker is open.
- Read the ticket's frames (`design/frames/fNN.png`), prototype screen key and PRD section before coding. MS-100 (#71) overrides the PRD; where it is silent, layout and copy follow the frame and business rules follow the PRD.
- PRD Appendix B element ids (`procDetail.start`) are used verbatim as `.accessibilityIdentifier` and analytics event names.
- One branch and one PR per ticket; the body says `Closes #N` (`Refs #N` for a fix to a closed ticket).
- The build thread runs the review loop, never the builder: once CI has finished it runs the `pr-reviewer` agent, which squash-merges when nothing blocks. On `CHANGES_REQUESTED` it resumes the ticket's builder, which fixes every finding on the same branch, pushes and waits for CI, and then runs the reviewer again. After 2 rounds without a merge, or on `NEEDS_OWNER`, stop and ask Grigor. A re-run only because another PR merged first does not count as a round.
- After a merge: move the ticket's Notion card to Feature QA, fast-forward the Mac checkout (`/usr/bin/git -C /Users/grigorgrigoryan/Documents/Personal/Dentory merge --ff-only origin/claude/project-thread-ocu7tf` after a fetch; nothing is built or edited there), and delete the builder's scratch directory. `docs/handoff/build-state.md` gets the merged row in the next PR.

## Models
- Opus 5.5 (`claude-opus-5-5`) builds: the build thread and `ticket-builder`. Sonnet 5.5 (`claude-sonnet-5-5`) reviews: `pr-reviewer`.
- Fable 5.1 (`claude-fable-5-1`) only for a product decision the PRD and MS-100 leave open, or a ticket judged too hard for Opus: say so in the thread, then run that work as an Agent call with `model: "fable"`. The thread itself switches model only when Grigor asks.
- Pass the model on every Agent call too (`"opus"` for `ticket-builder`, `"sonnet"` for `pr-reviewer`), so a definition the session loaded before a change still runs on the right model.

## Stack (MS-100 D1)
Swift 6, SwiftUI, Observation, iOS 17+, iPhone and iPad; XcodeGen; Swift Package Manager (`supabase-swift`). Supabase (Postgres with RLS, Auth, Storage, Edge Functions, pg_cron); the Claude API for invoice reading, server side only; Stripe on hosted pages; Resend; APNs.

## Rules
- Stock changes only through the Postgres RPC functions of the transaction engine (MS-106). Never write `batches`, `transactions` or `open_items` from the app.
- The `transactions` table is append-only; products are archived, never deleted.
- UI uses only `Dentory/Core/DesignSystem` tokens and components (MS-102). No raw colors, font names or magic numbers in feature code.
- Copy: sentence case, numbers first, no exclamation marks, no emoji, no "please". Use the PRD §7 vocabulary exactly.
- Role gating hides controls; never show a disabled control because of role. The database enforces permissions too (MS-105).
- No patient or appointment data anywhere.
- Secrets live only in the git-ignored `Config/Secrets*.xcconfig` and in `supabase secrets set` on hosted projects, never in the repo or a chat. Staging gets `supabase db push` after a database merge; prod is pushed by hand, never from CI.

## Commands
- `make project` after adding or removing files (the `.xcodeproj` is generated; only `Package.resolved` is committed).
- `make lint` (strict SwiftLint), `make build`, `make test`, `make uitest`. CI builds with `WARNINGS_AS_ERRORS=YES`, so run `make test WARNINGS_AS_ERRORS=YES` before pushing.
- Database: `make db-start`, then `make db-reset db-test`, then `make seed-demo db-test` (CI runs pgTAP after both). Every migration (`supabase migration new <name>`) gets a pgTAP test.
- Edge Functions: `supabase/functions/<name>/index.ts`, shared code in `_shared/`, checked by `make functions-check`. They refuse with `{ "error": { "code", "message", "field" } }`, which the app maps with `AppError(functionError:)`.
