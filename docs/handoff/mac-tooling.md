# Mac tooling and CI quirks

Facts about building, testing and screenshotting Dentory on Grigor's Mac that each cost a debugging detour. The `ticket-builder` and `pr-reviewer` agents read this before they start; the build thread keeps the same notes in its memory. Re-check simulator ids with `xcrun simctl list devices available` if a launch fails.

## Commands on this Mac
- `gh` fails with "bad CPU type" unless run as `PATH=/usr/bin:$PATH gh …` (an Intel-only `/usr/local/bin/git` shadows Apple's git); call git as `/usr/bin/git` in scripts.
- From a clone outside the main checkout (a fresh clone has no `.xcodeproj`, so `make project` comes first), reuse the main checkout's packages and keep build output in your scratch directory: `make project <targets> WARNINGS_AS_ERRORS=YES SPM_DIR=/Users/grigorgrigoryan/Documents/Personal/Dentory/.build/spm SPM_FLAGS=-onlyUsePackageVersionsFromResolvedFile DERIVED_DATA=<scratch>/dd SIM_ID=<simulator id>`. Without `SPM_DIR` a clone downloads its own 2 GB of packages; without `DERIVED_DATA` it leaves gigabytes in `~/Library/Developer/Xcode/DerivedData`.
- After switching branches, `git checkout -- Dentory.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` if `make project` rewrote it.

## Simulators
- Builder tests: iPhone 16 iOS 18.4 `7A14DBA5-EF48-4F05-90A8-6501E7848984` (software keyboard hidden). Reviewers never use it: they create their own (`xcrun simctl create "Review PR <N>" "iPhone 16" com.apple.CoreSimulator.SimRuntime.iOS-18-4`), wait for `xcrun simctl bootstatus <id> -b`, pass its `SIM_ID`, and delete it in every case.
- Screenshots: iPhone 16 iOS 18.0 `D2130EAA-FD87-4F2D-A967-C2FE5B6CD898`, iPad Pro 11-inch (M4) `485B6A12-F5E9-41A9-840F-25FEC5026FE1`. Launch with `-uiTesting [-staff] -tab inventory -inventoryFilter Healthy`. The status bar override (`xcrun simctl status_bar <id> override --time 9:41 …`) holds only on a booted device and with `-parallel-testing-enabled NO`.
- A newly created simulator runs a first-boot migration that swallows taps: wait for `bootstatus -b` first. The first tap after `simctl launch` is often lost; make a harmless tap first. Capture with `xcrun simctl io <id> screenshot` and look at the file before uploading it.
- "Failed to get matching snapshots: … kAXErrorServerNotFound" is the simulator's accessibility server dying under load, not an assertion: reboot that simulator and rerun.
- `NotificationsUITests` need a simulator that never answered the notification prompt (7A14, or an erased one; the screenshot iPhone granted it).
- A `Dentory.app` copied out of DerivedData loses its signature: `codesign -f -s -` each .dylib, then `--deep` the app, before `xcrun simctl install`.

## What CI rejects that the Mac accepts
- CI runs `make project lint build test WARNINGS_AS_ERRORS=YES`, test code included (`try? #require(x)` is a "redundant #require" error). Run `make test WARNINGS_AS_ERRORS=YES`, not plain `make test`. CI never runs XCUITest: run the flows you touch.
- CI's SwiftLint fails lines over 120 characters that contain string interpolation, which local SwiftLint 0.62.2 passes. Before pushing: `awk 'length($0) > 120'` over the changed Swift files.
- CI builds with Xcode 26.3 (iOS 26.2 SDK); the Mac has Xcode 27.1, which accepts some Sendable captures CI rejects (a `PhotosPicker` label closure reading a main-actor view model: copy into `let`s first), and `let emails = lock.withLock { emails }` (name the local differently or write `self.emails`). Every UI test helper touching `XCUIApplication` or `XCUIElement` needs `@MainActor`.
- CI's database job runs every pgTAP file twice, after `db-reset` and again after `seed-demo.sql`: scope row counts to the test's own ids. Check with `make db-reset db-test`, then `make seed-demo db-test`.
- Check open PRs before naming a migration or pgTAP file (two branches once both took `20261019200000`). A migration that sorts before one already on staging needs `supabase db push --include-all` there.
- Failed CI logs: `gh run view --job <id> --log-failed` once the run ends; while it runs, `gh api --allow-escape-sequences repos/grigorhello/Dentory/actions/jobs/<id>/logs`.

## UI tests
- The tabs kept alive behind the selected one stay in the accessibility tree: query by ids unique to the screen (`inv.row[…]`), never by shared text. `.accessibilityIdentifier` on a non-element container renames its children.
- iOS writes times as "3:14\u{202F}PM" (narrow no-break space).
- `swipeLeft` on a small row moves too little: use `press(forDuration: 0.1, thenDragTo:)`. Confirmation-dialog buttons take `.accessibilityIdentifier`; a custom `ToggleStyle` switch is found with `descendants(matching: .any)[id]`.

## End-to-end flows (`make e2e`, MS-136)
- `make e2e` resets the local database, loads the demo clinic and runs `DentoryE2ETests` through the `DentoryE2E` scheme: the real Debug app against the stack, seven flows in about five minutes on this Mac. Pass the same `SPM_DIR`, `SPM_FLAGS`, `DERIVED_DATA` and `SIM_ID` as for `make test`. The `Dentory` scheme builds the target but skips it, which also means `-only-testing:DentoryE2ETests` cannot reach it there.
- The stack must run from the checkout under test: `supabase start` mounts the `supabase/functions` of the folder it ran in, so a stack started from another clone serves that clone's functions. `make e2e` stops then (`supabase stop`, then `make db-start` in the clone), and when `Config/Secrets.debug.xcconfig` exists, since it points Debug builds away from the stack.
- The edge runtime `supabase start` runs keeps serving the functions it compiled: `docker restart supabase_edge_runtime_Dentory` after editing one. After `supabase functions serve` exits the stack serves no functions until `supabase stop` and `supabase start` (a `supabase start` while running lists the edge runtime as stopped and leaves it). The runtime bundles only the modules a function imports, as a deployment does, so a file read at run time (`Deno.readFile`) is not there.
- Each flow launches with `-signedOut` and signs in, and says Not now to the notifications explainer the first sign-in on a simulator brings. Products and templates carry the seed's ids (`d0000000-0000-4000-8000-0000000002NN`, `…03NN`); rows keyed by ids the seed leaves random (batches, To buy lines, procedures) are found by their labels, with the identifier read once into a constant before the row can go away; Inventory rows through the search, since the lazy list holds only the rows on screen. The To buy checkbox is a toggle to XCUITest, not a button. The pushed screens hide the tab bar: go back before choosing a tab.
- The invoice flow launches with `-receiveFile <path>` (Upload PDF or image takes that file instead of Files), the fixture PDF in the checkout, which the simulator reads from the Mac's disk; `extract_invoice` reads it from its recorded answer (`supabase/README.md`, Invoice reading).
- GitHub's hosted runners, probed on 2026-10-26: the arm64 macOS runners have no virtualisation for colima ("Apple M1 (Virtual)", `kern.hv_support` 0 or missing). The Intel runner (`macos-15-intel`, 4 cores) has a hypervisor: colima started there in 6 to 8 minutes (once only after restarting its VM), and `supabase start` took 15 minutes in one run and did not finish in 25 in the other. Hence the flows run here and CI only compiles them (decisions log).

## Branches and screenshots
- Never stack PRs: the reviewer's `--delete-branch` closes a PR based on the merged branch. Merge the default branch in instead; parallel PRs that each add to `AppDependencies` conflict on every merge (keep both sides, the default branch's first). `AppDependencies.preview` sits at SwiftLint's 50-line body limit.
- PR screenshots go on the `pr-assets` branch: `gh api -X PUT repos/grigorhello/Dentory/contents/<dir>/<file>.png --input <json with message, branch "pr-assets", base64 content>` (`sha` when replacing), linked with that commit's sha on raw.githubusercontent.com.
- Email screenshots: headless Chrome (`--headless=new --user-data-dir=<scratch>`) has a 500 px minimum width, so render a 390 px view inside an iframe and crop with a small ImageIO Swift script (ffmpeg is Intel-only here).
