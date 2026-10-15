# MediSave

Dental inventory app for small clinics: iPhone and iPad, two roles (Admin, Staff). V1.1 is specified in `design/PRD-v1.1.md` and drawn in `design/frames/`.

## Working on a ticket
- Tickets are GitHub issues titled `MS-1NN · …`. Each one names its frames (`design/frames/fNN.png`), the prototype screen key and the PRD section. Read all three before coding.
- Decisions that override or fill gaps in the PRD are in issue `MS-100`. When the frame and the PRD text disagree and MS-100 is silent: layout and copy follow the frame, business rules follow the PRD.
- Use the PRD Appendix B element ids (e.g. `procDetail.start`) verbatim as `testID` and analytics event names.
- One branch and one PR per ticket; PR body says `Closes #N`.

## Stack (MS-100 D1)
Expo + React Native + TypeScript + expo-router, Supabase (Postgres with RLS, Auth, Storage, Edge Functions, pg_cron), Claude API for invoice reading, Stripe billing, Resend email, Expo push.

## Rules
- Stock changes only through the Postgres RPC functions of the transaction engine (MS-106). Never write `batches`, `transactions` or `open_items` from the app.
- The `transactions` table is append-only; products are archived, never deleted.
- UI uses only `src/ui/` tokens and components (MS-102). No raw hex colors or pixel values in feature code.
- Copy: sentence case, numbers first, no exclamation marks, no emoji, no "please". Use the PRD §7 vocabulary exactly.
- Role gating hides controls; never show a disabled control because of role. The database enforces permissions too (MS-105).
- No patient or appointment data anywhere.

## Commands
To be filled in by MS-101 (app, database, tests, e2e).
