# MediSave

Dental inventory app for small clinics: iPhone and iPad, two roles (Admin, Staff). V1.1 is specified in `design/PRD-v1.1.md` and drawn in `design/frames/`. The process, the current build state and the product knowledge for non-engineering work are in `docs/handoff/` (start with its README).

## Working on a ticket
- Follow the `medisave-ios` skill (`.claude/skills/medisave-ios/SKILL.md`) for every ticket: MVVM, feature folders, SOLID, tests, PR checklist. Use `swiftui-pro` to review SwiftUI code and `swift-concurrency` for concurrency errors.
- Tickets are GitHub issues titled `MS-1NN · …`. Build them in the order of [`docs/BUILD-ORDER.md`](docs/BUILD-ORDER.md); each issue starts with its build step and the issues blocking it. Do not start a ticket while a blocker is open.
- Each ticket names its frames (`design/frames/fNN.png`), the prototype screen key and the PRD section. Read all three before coding.
- Decisions that override or fill gaps in the PRD are in issue `MS-100`. When the frame and the PRD text disagree and MS-100 is silent: layout and copy follow the frame, business rules follow the PRD.
- Use the PRD Appendix B element ids (e.g. `procDetail.start`) verbatim as `.accessibilityIdentifier` and analytics event names.
- One branch and one PR per ticket; PR body says `Closes #N`.
- Review loop: once CI has finished on the PR, run the `pr-reviewer` agent (`.claude/agents/pr-reviewer.md`) on it. It squash-merges when nothing blocks. On `CHANGES_REQUESTED` the developer fixes every finding on the same branch, pushes, waits for CI and runs the reviewer again. After 3 rounds without a merge, or on `NEEDS_OWNER`, stop and ask Grigor. After a merge, move the ticket's Notion card to Feature QA.

## Stack (MS-100 D1)
Native iOS: Swift 6, SwiftUI, Observation, iOS 17+, iPhone and iPad, project generated with XcodeGen, packages via Swift Package Manager (`supabase-swift`). Supabase (Postgres with RLS, Auth, Storage, Edge Functions, pg_cron), Claude API for invoice reading (server side), Stripe billing (hosted pages), Resend email, APNs push.

## Rules
- Stock changes only through the Postgres RPC functions of the transaction engine (MS-106). Never write `batches`, `transactions` or `open_items` from the app.
- The `transactions` table is append-only; products are archived, never deleted.
- UI uses only `MediSave/Core/DesignSystem` tokens and components (MS-102). No raw colors, font names or magic numbers in feature code.
- Copy: sentence case, numbers first, no exclamation marks, no emoji, no "please". Use the PRD §7 vocabulary exactly.
- Role gating hides controls; never show a disabled control because of role. The database enforces permissions too (MS-105).
- No patient or appointment data anywhere.

## Commands
- `make project`: generate `MediSave.xcodeproj` from `project.yml` (generated and git-ignored except `Package.resolved`, which pins package versions; rerun after adding files).
- `make build`: build for the iOS Simulator. Add `WARNINGS_AS_ERRORS=YES` to fail on warnings, as CI does.
- `make test`: unit tests (Swift Testing) on the iPhone 16 simulator. `make uitest`: XCUITest flows.
- `make lint`: SwiftLint, strict. Raw colors and fonts outside `Core/DesignSystem` fail it.
- Supabase keys: copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` (git-ignored).
- `make db-start`: local Supabase stack in Docker (Studio at http://127.0.0.1:54323); `make db-stop` stops it. Debug builds talk to it by default.
- `make db-reset`: drop the local database, apply `supabase/migrations` in order, then `supabase/seed.sql`. `make db-test`: pgTAP tests in `supabase/tests/database`.
- New migration: `supabase migration new <name>`; give it a pgTAP test. CI runs `db-reset db-test` and `make functions-check` (Deno) on every PR.
- Hosted projects: `supabase link --project-ref <ref>` once, then `supabase db push` to staging after a merge. Pushing to prod is done by hand, never from CI. Keys live in `Config/Secrets*.xcconfig` (git-ignored), never in the repo.
