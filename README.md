# MediSave

Dental inventory app for small clinics, native SwiftUI for iPhone and iPad (iOS 17+, Swift 6) on Supabase. Product spec: `design/PRD-v1.1.md`. Build rules: `CLAUDE.md`. Tickets and their order: `docs/BUILD-ORDER.md`.

## Setup
1. Install Xcode 26 or later, then `brew install xcodegen swiftlint`.
2. `cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig` and fill in the Supabase URL and anon key (optional until the app talks to Supabase).
3. `make project` and open `MediSave.xcodeproj`. The project file is generated from `project.yml` and not committed; rerun `make project` after pulling or adding files.

## Commands
| Command | What it does |
|---|---|
| `make project` | Generate `MediSave.xcodeproj` from `project.yml` (XcodeGen) |
| `make build` | Build the app for the iOS Simulator |
| `make test` | Run the unit tests (Swift Testing) on the iPhone 16 simulator |
| `make uitest` | Run the UI tests (XCUITest) on the iPhone 16 simulator |
| `make lint` | Run SwiftLint in strict mode |

Add `WARNINGS_AS_ERRORS=YES` to fail on any compiler warning (CI does). `SIM_NAME="iPad Pro 11-inch (M4)"` runs the tests on another simulator.

CI (`.github/workflows/ci.yml`) runs `make project lint build test WARNINGS_AS_ERRORS=YES` on every pull request.
