# MediSave

Dental inventory app for small clinics: iPhone and iPad, two roles (Admin, Staff). V1.1 is specified in `design/PRD-v1.1.md` and drawn in `design/frames/`.

## Working on a ticket
- Follow the `medisave-ios` skill (`.claude/skills/medisave-ios/SKILL.md`) for every ticket: MVVM, feature folders, SOLID, tests, PR checklist. Use `swiftui-pro` to review SwiftUI code and `swift-concurrency` for concurrency errors.
- Tickets are GitHub issues titled `MS-1NN · …`. Build them in the order of [`docs/BUILD-ORDER.md`](docs/BUILD-ORDER.md); each issue starts with its build step and the issues blocking it. Do not start a ticket while a blocker is open.
- Each ticket names its frames (`design/frames/fNN.png`), the prototype screen key and the PRD section. Read all three before coding.
- Decisions that override or fill gaps in the PRD are in issue `MS-100`. When the frame and the PRD text disagree and MS-100 is silent: layout and copy follow the frame, business rules follow the PRD.
- Use the PRD Appendix B element ids (e.g. `procDetail.start`) verbatim as `.accessibilityIdentifier` and analytics event names.
- One branch and one PR per ticket; PR body says `Closes #N`.

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
To be filled in by MS-101 (app, database, tests, e2e).
