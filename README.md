# MediSave

Dental inventory app for small clinics, native SwiftUI for iPhone and iPad (iOS 17+, Swift 6) on Supabase. Product spec: `design/PRD-v1.1.md`. Build rules: `CLAUDE.md`. Tickets and their order: `docs/BUILD-ORDER.md`.

## Setup
1. Install Xcode 26 or later, then `brew install xcodegen swiftlint`.
2. Install Docker Desktop and the Supabase CLI (`brew install supabase/tap/supabase`), then `make db-start`. Debug builds talk to this local stack; nothing else is needed to run the app.
3. `make project` and open `MediSave.xcodeproj`. The project file is generated from `project.yml` and not committed, except `Package.resolved`, which pins the Swift package versions (commit it when they change). Rerun `make project` after pulling or adding files.
4. Only for Release builds and TestFlight: `cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig` and fill in the hosted project's URL and anon key (see Database below).

## Commands
| Command | What it does |
|---|---|
| `make project` | Generate `MediSave.xcodeproj` from `project.yml` (XcodeGen) |
| `make build` | Build the app for the iOS Simulator |
| `make test` | Run the unit tests (Swift Testing) on the iPhone 16 simulator |
| `make uitest` | Run the UI tests (XCUITest) on the iPhone 16 simulator |
| `make lint` | Run SwiftLint in strict mode |

Add `WARNINGS_AS_ERRORS=YES` to fail on any compiler warning (CI does). `SIM_NAME="iPad Pro 11-inch (M4)"` runs the tests on another simulator. CI adds `SPM_FLAGS=-onlyUsePackageVersionsFromResolvedFile` so it builds exactly the committed package versions.

CI (`.github/workflows/ci.yml`) runs `make project lint build test WARNINGS_AS_ERRORS=YES` on every pull request, and the database job below next to it.

## Database
Everything lives in `supabase/`: `config.toml` (local stack), `migrations/` (one timestamped SQL file per change), `seed.sql` (demo data, MS-109), `functions/` (Deno Edge Functions, one folder each), `tests/database/` (pgTAP).

| Command | What it does |
|---|---|
| `make db-start` | Start the local stack in Docker: API on http://127.0.0.1:54321, Studio on http://127.0.0.1:54323 |
| `make db-stop` | Stop it |
| `make db-reset` | Drop the local database, apply `supabase/migrations` in order, then `supabase/seed.sql` |
| `make db-test` | Run the pgTAP tests in `supabase/tests` |
| `make functions-serve` | Serve the Edge Functions locally (`/functions/v1/<name>`) |
| `make functions-check` | Type-check the Edge Functions (`brew install deno`) |

Adding a change: `supabase migration new <name>` creates the file under `supabase/migrations`; write the SQL, add a pgTAP test next to the others, then `make db-reset db-test`. `supabase gen types --lang=swift --local` prints Swift types for the current schema (MS-154 wires them into the app). CI (`database` job, Ubuntu) runs `supabase db start`, `make db-reset db-test` and `make functions-check` on every pull request and fails when a test fails.

**Hosted projects.** Two Supabase projects belong to Grigor's account: staging (the pilot clinic) and, before TestFlight, prod. To work with one from your Mac:
1. `supabase login` once; it opens the browser and stores your token in the keychain.
2. `supabase link --project-ref <ref>`; the ref is the 20-character id in the dashboard URL (`supabase.com/dashboard/project/<ref>`). It asks for the database password and writes only `supabase/.temp` (git-ignored).
3. `supabase db push` applies the migrations that are not on the hosted project yet. Do this for staging after a merge. Pushing to prod is a deliberate manual step, never done from CI.

The app's keys for a hosted project (Project Settings → API: the URL and the `anon public` key) go in `Config/Secrets.xcconfig` for Release builds, or `Config/Secrets.debug.xcconfig` to point a Debug build at it; both are git-ignored and must stay out of the repo and of chat. The local stack needs no secrets: its URL and anon key are the same on every machine and sit in `Config/Debug.xcconfig`.
