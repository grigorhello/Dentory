# M0 · Foundations

## MS-100 · Record the V1.1 build decisions and close the design gaps
meta: milestone=M0; priority=P0; type=decision; area=product; size=1; frames=f1,f2,f9,f10,f20; screens=; prd=§10 Gaps, §9; depends=

### Why
PRD v1.1 is "ready for development", but it leaves six gaps (G1–G6), and the drawn screens differ from the PRD text in a few places. Every later ticket assumes the answers below. This ticket exists so Grigor can confirm or change them in one place before building starts; until he changes one, treat it as decided.

### Decisions (defaults, Claude as product owner)
| ID | Topic | Decision |
|---|---|---|
| D1 | Stack | Native iOS app: Swift 6, SwiftUI, Observation, iOS 17+, one target for iPhone and iPad, MVVM in feature folders per the `medisave-ios` skill (changed from Expo by Grigor, 2026-10-15). Supabase for Postgres, Auth, Storage, Edge Functions and cron (`supabase-swift` client). Claude API for invoice reading (server side). Stripe for billing (hosted pages). Resend for email. APNs for push. Android is out of scope for V1.1. |
| D2 | Source of truth | Layout and copy: the drawn frame wins. Business rules: PRD v1.1 wins. Where they conflict and this table is silent, follow the frame and note it in the PR. |
| D3 | Element ids | The ids in PRD Appendix B (e.g. `procDetail.start`) are used verbatim as SwiftUI `.accessibilityIdentifier` values (so XCUITest finds them) and as analytics event names. |
| D4 | Google sign-in | Frames f1 and f2 show "Continue with Google"; the PRD does not. Not in V1.1. Remove the button. |
| D5 | Activity history row "Full → 50%" (f9) | Leftover from v1.0 level tracking. Do not build level updates; multi-use history rows read "Opened a new bottle" / "Finished". |
| D6 | Product detail quantity label (f20) | The frame labels the big number "Available" and shows "System estimate · N used in 30 days". Build as drawn. |
| D7 | Inventory value screen (f10) | The frame shows more than the PRD (Expiring ≤ 90 d, Used 30 d, Received 30 d, highest value products). Build as drawn. |
| G1 | Multi-use flag | Add a "Multi-use (bottle, syringe, kit)" switch under Units in New / Edit product. |
| G2 | Staff label | Both roles see "Add to buy". |
| G3 | Low for multi-use | Unopened only. |
| G4 | Password reset, invite expiry, resend | Standard email-link flows, 7-day invitation links, resend from Team. Screens built from existing components (see MS-112, MS-113). |
| G5 | Trial ended | Read-only mode: banner on Home and Billing; any write opens a sheet pointing to Billing (MS-142). |
| G6 | Onboarding checklist | Stays removed. The first Receive delivery seeds products. |
| D8 | Expiry warning setting | Stored as a set of thresholds: {30,60,90}, {60,90} or {90}. A batch is Expiring when it expires within the largest threshold; an alert fires each time a batch crosses one of the chosen thresholds. |
| D9 | Which batch a change hits | Deductions (procedure, count down, adjust down, open a bottle) take from the soonest-expiring batch first, undated quantity last. Increases from count or adjust go to the undated batch (so they show as Missing expiry until dated). Stock may go negative; negatives sit on the undated batch. |
| D10 | Undo | Undo is a server call that writes reversal transactions for one action. Available for 10 seconds after the action, only to the same user (the toast shows it for 3.2 s). |
| D11 | Billing on iOS | Payment happens on a Stripe-hosted web page opened from the app (Stripe Checkout, then Customer Portal). No in-app purchase. Before App Store submission confirm this is accepted for a B2B clinic subscription (see MS-152). |
| D12 | Links in emails | Invitation and password links are https links on a MediSave domain that open the app (universal links) and fall back to a simple web page. Grigor to pick the domain; until then use the Supabase project URL for testing. |
| D14 | Clinic settings fields (f33) | The frame shows Currency and Time zone; the PRD lists logo, name, city, country. Build both: logo, name, city, country, plus Currency and Time zone prefilled from the country and device, editable. |
| D13 | Categories | Per clinic, seeded with: Anesthetic, Restorative, Endodontics, Impression, Preventive, Surgical, PPE, Sterilization, Disposable, Other. Admin picks from the list or types a new one in New product. |

### Action items
- [ ] Grigor reads this table and comments on any row he wants changed.
- [ ] Pick the production domain for D12.
- [ ] When a decision changes, edit this ticket and every ticket it names.

### Acceptance criteria
- [ ] Every row is either confirmed or replaced by Grigor.

## MS-101 · Set up the iOS app project for iPhone and iPad
meta: milestone=M0; priority=P0; type=tech; area=platform; size=3; frames=f6,f36; screens=; prd=§9; depends=MS-100

### Goal
A native SwiftUI app that builds and runs on iPhone and iPad simulators, with the folder structure, build settings, lint and test targets every later ticket assumes, and CI that builds and tests every pull request. No features yet.

### Read first
`.claude/skills/medisave-ios/SKILL.md` (architecture standard). This ticket creates exactly the layout in its section 2 and the build settings in its section 6.

### Scope
- **Project generation:** XcodeGen `project.yml` at the repo root; `MediSave.xcodeproj` is generated and git-ignored (avoids project-file merge conflicts across 50+ PRs). `make project` runs `xcodegen generate`.
- **Targets:** `MediSave` (app), `MediSaveTests` (Swift Testing), `MediSaveUITests` (XCUITest).
- **Settings:** app name MediSave, bundle id `com.medisave.app` (placeholder until Grigor confirms), iOS 17.0 deployment target, `TARGETED_DEVICE_FAMILY = 1,2` (iPhone and iPad), iPhone portrait only, iPad all orientations, Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, warnings as errors in CI.
- **Configurations:** Debug and Release with `Config/Debug.xcconfig` / `Release.xcconfig` holding `SUPABASE_URL` and `SUPABASE_ANON_KEY` (read into `Info.plist`); `Config/Secrets.example.xcconfig` committed, real values git-ignored.
- **Folders:** create the skeleton from the skill (`App/`, `Core/DesignSystem`, `Core/Domain`, `Core/Data`, `Core/Navigation`, `Core/Support`, `Features/`, `Resources/`), each with a short `README.md` line saying what belongs there. No placeholder protocols or base classes.
- **App entry:** `MediSaveApp` showing a temporary `RootView` with four tabs (Home, Inventory, Procedures, To buy) whose screens say only the tab name. MS-103 replaces it with the real shell.
- **Packages (SPM, via `project.yml`):** `supabase-swift` only. Nothing else in this ticket.
- **Lint and format:** SwiftLint with a short `.swiftlint.yml` (default rules plus `force_unwrapping`, `implicitly_unwrapped_optional`, file length 400, type body length 300) and a custom rule that rejects `Color(red:`, `Color(hex:`, `UIColor(` and `Font.custom(` outside `MediSave/Core/DesignSystem/`.
- **Makefile:** `make project`, `make build`, `make test` (unit tests, iPhone 16 simulator), `make uitest`, `make lint`. Add the commands to the "Commands" section of `CLAUDE.md` and to `README.md`.
- **CI (GitHub Actions, `macos-15` runner, latest stable Xcode):** on every pull request: install XcodeGen and SwiftLint, `make project lint build test`. Cache SPM.
- **Repo hygiene:** `.gitignore` for Xcode, SPM and secrets; `.github/pull_request_template.md` with `Closes #`, screenshots, and the PR checklist from the skill.

### Out of scope
Supabase project and database (MS-153), design system (MS-102), app core and dependency wiring (MS-154), real navigation (MS-103), TestFlight (MS-152).

### Action items
- [ ] Rename the default branch `claude/project-thread-ocu7tf` (it holds the design handoff and skills) to `main` in GitHub Settings → Branches. Renaming keeps every commit, so the frame links in tickets keep working.
- [ ] Grigor confirms the bundle id and Apple Developer team.

### Acceptance criteria
- [ ] From a clean clone, `make project build` succeeds and the app launches on the iPhone 16 and iPad Pro 11" simulators showing four tabs; iPad rotates, iPhone stays portrait.
- [ ] `make test` runs one passing Swift Testing test and `make uitest` one XCUITest that taps all four tabs.
- [ ] CI is green on a pull request and fails on a SwiftLint error, a compiler warning or a failing test.
- [ ] Adding `Color(red: 1, green: 0, blue: 0)` in `Features/` fails lint.

## MS-153 · Set up Supabase locally and in CI
meta: milestone=M0; priority=P0; type=tech; area=platform; size=2; frames=; screens=; prd=§9; depends=MS-100

### Goal
A local Supabase stack any ticket can migrate, seed and test against, and a CI job that proves migrations and SQL tests pass.

### Scope
- `supabase init` at the repo root: `supabase/migrations/`, `supabase/functions/` (Deno Edge Functions), `supabase/seed.sql`, `supabase/tests/` (pgTAP).
- `make db-start` (`supabase start`), `make db-reset` (`supabase db reset`, applies migrations and seed), `make db-test` (`supabase test db`), `make functions-serve`.
- One placeholder pgTAP test so the pipeline is real.
- CI job (Ubuntu runner, parallel to the iOS job from MS-101): Supabase CLI, `supabase db start`, `supabase db reset`, `supabase test db`, `deno check` on functions.
- Hosted projects: `medisave-staging` and `medisave-prod` in Supabase (Grigor's account). Document in `README.md` how to link and push migrations (`supabase link`, `supabase db push`); pushing to prod is manual, never from CI.
- Local app config: `Config/Debug.xcconfig` points at the local stack (`http://127.0.0.1:54321` + local anon key) by default.

### Out of scope
Tables and policies (MS-104, MS-105).

### Action items
- [ ] Grigor creates the two Supabase projects (or invites the team) and stores their keys in GitHub Actions secrets for later deploy tickets.

### Acceptance criteria
- [ ] From a clean clone, `make db-start db-reset db-test` passes.
- [ ] CI runs the database job on every pull request and fails when a pgTAP test fails.

## MS-154 · Build the app core: dependencies, data layer and session
meta: milestone=M0; priority=P0; type=tech; area=platform; size=3; frames=; screens=; prd=§9; depends=MS-101,MS-153

### Goal
The small set of shared building blocks every feature uses, exactly as the `medisave-ios` skill describes (section 3), so feature tickets only add a view, a view model and a repository.

### Scope
- `App/AppDependencies.swift`: `struct AppDependencies` holding the shared services below, with `static func live()` and `static func preview()` (fakes with demo data). Injected through a custom `EnvironmentKey`. Feature repositories are added to it by their own tickets.
- `Core/Data/SupabaseClientProvider.swift`: one `SupabaseClient` built from the xcconfig values.
- `Core/Data/RPCClient.swift`: `protocol RPCCalling` + Supabase implementation. `call<Params: Encodable & Sendable, Result: Decodable & Sendable>(_ function: String, params:) async throws -> Result`. Generates and attaches an `idempotency_key` UUID unless one is passed (MS-106 contract). Maps Postgres error codes to `AppError` (`read_only` → `.readOnly`, `42501` → `.forbidden`, network → `.network`).
- `Core/Data/AppError.swift`: the enum from the skill, with `userMessage` copy from PRD §7 ("Couldn't save. Try again.").
- `Core/Domain/Session.swift` + `Core/Data/AuthService.swift` (`protocol AuthServicing`): signed-in user, current clinic id, role (`admin | staff`), sign in, sign out, session restore on launch. `@Observable final class SessionStore` holds it for the UI.
- `Core/Support/Clock.swift` (`protocol Clock` with `now`; live and fixed), `Core/Support/NetworkMonitor.swift` (`protocol NetworkMonitoring`, live with `NWPathMonitor`), `Core/Support/Formatters.swift` (money in clinic currency, quantity + unit, dates and "in N days" in the clinic time zone).
- `MediSaveTests/Support/`: fakes for each protocol (`FakeRPCClient` records calls and returns canned results, `FakeAuthService`, `FixedClock`, `FakeNetworkMonitor`).
- `RootView` switches between a signed-out placeholder and the tabs based on `SessionStore` (MS-110 builds the real Sign in).

### Out of scope
Design system (MS-102), navigation shell and overlays (MS-103), offline queue and retries (MS-108).

### Acceptance criteria
- [ ] Unit tests: `RPCClient` attaches an idempotency key and maps `read_only`, permission and network errors; formatters render "$1,234.50", "54 cartridges", "in 12 days" for a fixed clock and time zone; `SessionStore` restores a stored session.
- [ ] `#Preview` blocks can build any later screen with `AppDependencies.preview()` and no network.
- [ ] No singletons or globals besides `MediSaveApp` building `AppDependencies.live()`.

## MS-102 · Port the MediSave design system to SwiftUI
meta: milestone=M0; priority=P0; type=tech; area=platform; size=5; frames=f13,f20,f23,f25; screens=; prd=§7 UX and UI standards; depends=MS-101

### Goal
Every screen is built only from tokens and components in `MediSave/Core/DesignSystem/`. No raw colors, font names or magic numbers in feature code.

### Source
`design/project/_ds/medisave-design-system-1666cb0d-4269-4a87-8f99-be4e150e5326/`: `tokens/*.css` (colors, typography, spacing, radius, elevation), `_ds_bundle.js` (the web components: Button, IconButton, Badge, Card, Icon, Tabs, Tag, Dialog, Toast, Tooltip, Checkbox, Input, Radio, Select, Switch), `readme.md` (rules). The prototype `design/project/MediSave Mobile.dc.html` shows how each component is used on mobile.

### Scope
1. **Tokens** (`DesignSystem/Tokens/`): every CSS variable from `tokens/colors.css`, `spacing.css`, `radius.css`, `elevation.css`, `typography.css` as Swift constants with the same names in lowerCamelCase: `Color.ms.primary`, `Spacing.lg`, `Radius.md`, `Shadow.card`. Colors live in the asset catalog (`Colors/` folder, one color set per token) so they can gain a dark variant later; V1.1 is light only. Motion: `Motion.fast` 0.12 s, `Motion.base` 0.18 s, easing `cubic-bezier(.2,0,0,1)` as a custom `Animation.timingCurve`.
2. **Type:** bundle Outfit 400/500/600 and Inter 400/500/600/700 (Google Fonts, OFL) in `Resources/Fonts`, registered in Info.plist. `TextStyle` enum (`display32`, `title24`, `body14`, `caption12`, `eyebrow14`, `mono`) built with `Font.custom(_:size:relativeTo:)` so Dynamic Type scales them; mono uses the system monospaced font.
3. **Icons:** the Lucide icons the prototype uses (ChevronLeft, ChevronRight, Plus, Minus, X, Check, Search, Pencil, ClipboardCheck, ClipboardList, ShoppingCart, SlidersHorizontal, Bell, User, Truck, Camera, FileUp, Info, LayoutGrid, Package, Users, Settings, CreditCard, Download, LifeBuoy, LogOut, UserPlus) as SVG template images in `Assets.xcassets/Icons` (Lucide is ISC licensed), wrapped in `enum Icon: String` and an `IconView(_:size:)` (default 20 pt, stroke 1.75 as exported).
4. **Components** with the variants the web bundle has, adapted to touch (44 pt minimum hit target), each in its own file with `#Preview`s for every state:
   - `MSButton` primary (blue) · secondary (ink) · tertiary (ink hairline) · text · danger; sizes small/medium; `icon`, `isLoading`, `isDisabled`, full width. Primary action height 48. Implement as a `ButtonStyle` so plain `Button` works.
   - `IconButton`, `StatusBadge` (Healthy=success, Low=warning, Out of stock=danger, Expiring=warning, Missing expiry=info; invoice states Matched, Possible match, New product, Needs review, Created, Skipped), `CardView` (cream-soft, radius 12, padding 16), `MSTextField` (label, hint, inline danger error), `MSPicker` (select), `MSToggle`, `MSCheckbox`, `SegmentedControl` (cream-soft track, 2–3 options with counts), `FilterChip` (ink fill when active), `QuantityStepper` (40×40 −/+, hairline, radius 6, value 36–44 pt wide, value turns primary blue when it differs from its reference value, minimum 0), `ListCard` + `ListRow` (title 14 ink, caption 12 secondary, right value or badge, chevron only when it navigates, 1 pt line dividers), `Eyebrow` (uppercase Outfit 14, tracking 1), `Notice` (soft tinted one-line box: info, warning, success, danger), `EmptyStateView` (hairline frame + one caption), `SkeletonRow`, `FloatingAddButton` (round 56 pt +, bottom right).
5. **Catalog:** `DesignSystemCatalogView` (Debug builds only, opened from a hidden long-press on the Home title) rendering every component and variant, for visual review against `design/frames/*.png`.

### Rules to encode (from PRD §7)
- Status is always text + color, never color alone. Badges use soft tint, never a large fill.
- One blue primary per screen. Danger buttons only inside confirmation sheets.
- Text ≥ 12 pt, body 14. Dynamic Type up to the Large step without truncation.
- The SwiftLint rule from MS-101 keeps raw colors and fonts out of `Features/`.

### Acceptance criteria
- [ ] The catalog shows every component in every state (default, pressed, disabled, loading, error).
- [ ] Side by side with `design/frames/f13.png`, `f20.png`, `f23.png`, `f25.png`, steppers, badges, buttons and cards match in size, color, radius and type.
- [ ] Unit tests cover `QuantityStepper` minimum 0 and the "differs from reference" color logic (kept in a small testable model, not in the view).

## MS-103 · Build the app shell: tabs, pushed screens, sheets and toasts
meta: milestone=M0; priority=P0; type=tech; area=platform; size=5; frames=f6,f11,f16,f25,f13,f36; screens=home,proc,inv,order,procDetail; prd=§3 Navigation, §7; depends=MS-102,MS-154

### Goal
The navigation frame and the three shared overlays every feature uses, built once.

### Scope
- **Tab bar** (`TabView` with `AppTab` enum, one `NavigationStack` with a typed path per tab; 4 tabs, Lucide icons as in `design/frames/f25.png`): Home (LayoutGrid) · Inventory (Package) · Procedures (ClipboardCheck) · To buy (ClipboardList). Active tab in primary blue. To buy carries a red count badge = number of items with status To buy (live from MS-128; hide at 0).
- **Root screen header**: date or context eyebrow, 32 px Outfit 500 title, 20 px side padding, cream page `colorCanvas`.
- **Pushed screen header**: 44 px back chevron, 24 px title, optional subtitle line (e.g. "Patterson Dental · INV-10092 · $449.00"), optional right text action (Edit, Save). No tab bar on pushed screens.
- **Pinned primary bar**: bottom bar with hairline top, one full-width 48 px primary button (+ optional caption above it, e.g. "Resolve every line to continue."), safe-area aware.
- **Bottom sheet**: `MSSheet` (SwiftUI `.sheet` with custom detents and presentation background, or a custom overlay if the drawn look cannot be matched) with 20 px top radius, 36×4 grab handle, scrim `rgba(32,21,21,.4)`, 180 ms fade, slide ≤ 8 px, tap scrim or swipe down to close, keyboard avoiding. Title 24 px, one caption line, fields, full-width primary last. A `SheetList` variant: search field on top, 360 px scrolling list.
- **Toast**: `ToastCenter` (`@Observable`, in `AppDependencies`) shown by an overlay at the root; dark ink card above the tab bar (or above the pinned bar), title + one detail line, 3.2 s, optional Undo text button. One toast at a time; a new one replaces the old.
- **Offline banner**: one-line banner under the header when offline (driven by `NetworkMonitoring` from MS-154); see MS-108 for queued writes.
- **iPad**: content max width 720, centred; sheets centred at the same width; same bottom tabs (no sidebar, no split view). See `design/frames/f36.png`–`f38.png`.
- Role gating: `SessionStore.role` (`admin | staff`) and a `.adminOnly()` view modifier that removes the view for Staff. Role gating hides controls; it never renders a disabled control.
- `ContentColumn` container that caps width at 720 pt and centres it; every screen uses it.

### Acceptance criteria
- [ ] Four tabs switch without losing scroll position; pushed screens hide the tab bar.
- [ ] A demo sheet and toast in the design-system catalog behave as specified (timing, scrim tap, Undo callback).
- [ ] On iPad landscape and portrait, content is capped at 720 and centred.
- [ ] XCUITest smoke flow visits all four tabs and opens one pushed screen and one sheet.

## MS-104 · Create the database schema
meta: milestone=M0; priority=P0; type=tech; area=platform; size=5; frames=; screens=; prd=§4 Data model, §9 Audit; depends=MS-153,MS-100

### Goal
All tables for V1.1 in one migration set, isolated per clinic, append-only where the PRD says so.

### Tables (all have `id uuid pk default gen_random_uuid()`, `created_at timestamptz default now()`; every business table has `clinic_id uuid not null`)
- `clinics`: name, logo_path, city, country (ISO 3166 alpha-2), currency (derived from country, ISO 4217), expiry_thresholds int[] default {30,60,90}, email_digest bool default false, trial_ends_at timestamptz, subscription_status text (trialing|active|past_due|canceled|read_only), promo_lifetime_50 bool default false, stripe_customer_id, stripe_subscription_id, billing_emails text[].
- `profiles`: user_id (pk, references auth.users), full_name.
- `memberships`: clinic_id, user_id null until accepted, email, full_name, role (admin|staff), status (active|invited|revoked), invited_by, invited_at, invite_token_hash, invite_expires_at. Unique (clinic_id, lower(email)).
- `categories`: clinic_id, name, position. Unique (clinic_id, lower(name)).
- `products`: clinic_id, name, category_id, unit (counted-in, e.g. cartridges), pack_unit null (e.g. box), pack_size int null (>1 when pack_unit set), minimum numeric, target numeric, supplier text null, location text null, tracking (countable|multi_use), last_unit_cost numeric null (per counted unit), archived_at null.
- `batches`: product_id, clinic_id, expiry_month date null (first day of month; null = Missing expiry), lot text null, qty numeric (may be negative only on the undated batch). Index (product_id, expiry_month).
- `open_items`: product_id, clinic_id, opened_by, opened_at, opened_in_event_id null, finished_at null, finished_by null.
- `procedure_templates`: clinic_id, name, archived_at. `procedure_template_items`: template_id, product_id, default_qty (multi-use default 0), position.
- `procedure_events`: clinic_id, template_id null, name (snapshot), started_by, started_at, cancelled_at null, cancelled_by null, cancel_note null. `procedure_event_items`: event_id, product_id, qty. `procedure_event_openings`: event_id, product_id, open_item_id.
- `to_buy_items`: clinic_id, product_id, qty, qty_edited bool, source (auto|manual), status (to_buy|ordered|received), added_by null, ordered_at, ordered_by, received_at, invoice_id null.
- `invoices`: clinic_id, storage_path, source (camera|file|manual), status (reading|ready|failed|confirmed|discarded), supplier, number, invoice_date, total, currency, raw_extraction jsonb, created_by, confirmed_at, confirmed_by. `invoice_lines`: invoice_id, n, raw, qty, unit, unit_price, line_total, state (matched|possible_match|new_product|needs_review|created|skipped), suggested_product_id, product_id, lot, expiry_month.
- `supplier_aliases`: clinic_id, supplier, raw_text_normalized, product_id (learned on confirm; used for matching).
- `transactions` (append-only ledger): clinic_id, product_id, batch_id null, open_item_id null, type (receiving|procedure|count|adjustment|disposal|cancellation), delta numeric, qty_before, qty_after (product totals), by_user, at, ref_type (invoice|procedure_event|count_session|manual|undo), ref_id, ref_label (e.g. "Invoice INV-10092", "Root canal"), reason (adjust/disposal reason), note, reverses_id null, action_id uuid (groups rows written by one user action, used by Undo).
- `alerts`: clinic_id, kind (out_of_stock|low|expiring|missing_expiry|invoice_ready), product_id null, batch_id null, invoice_id null, threshold_days null, opened_at, resolved_at null. Unique open alert per (kind, product_id, batch_id, invoice_id, threshold_days) where resolved_at is null.
- `alert_reads`: user_id, clinic_id, last_seen_at (for the bell dot).
- `push_tokens`: user_id, token, platform, updated_at.
- `export_jobs`: clinic_id, requested_by, status, file_path, created_at, finished_at.

### Rules
- `transactions` has no UPDATE or DELETE grants for any role; a trigger raises on attempts.
- Products are never deleted, only archived.
- Quantity helpers as SQL views: `product_stock` (product_id, unopened = Σ batches.qty, open_count = count open_items where finished_at is null, quantity = unopened + open for multi-use, Σ batches for countable, missing_expiry_qty, soonest_expiry).
- `seed.sql` seeds nothing clinic-specific (demo data is MS-109).

### Acceptance criteria
- [ ] `supabase db reset` applies cleanly; generated types compile.
- [ ] SQL tests: UPDATE/DELETE on transactions fails; `product_stock` returns correct unopened/open/quantity for a countable and a multi-use product with an undated batch.

## MS-105 · Isolate clinics and enforce Admin and Staff permissions in the database
meta: milestone=M0; priority=P0; type=tech; area=auth; size=3; frames=; screens=; prd=§2 Users and roles, §9 Privacy; depends=MS-104

### Goal
A user can only ever read or change their own clinic's data, and Staff cannot do Admin-only things even by calling the API directly. The app hides Admin controls (MS-103), but the database is the real gate.

### Scope
- RLS on every table: `clinic_id in (select clinic_id from memberships where user_id = auth.uid() and status = 'active')`.
- SQL helpers: `current_role_in(clinic_id) returns text`, `is_admin(clinic_id)`, `clinic_can_write(clinic_id)` (false when the trial ended without payment, see MS-142).
- All stock changes go through SECURITY DEFINER RPC functions (MS-106); direct INSERT on batches, transactions, open_items is revoked from `authenticated`.
- Permission matrix (from PRD §2), enforced in RPCs and RLS:

| Capability | Admin | Staff |
|---|---|---|
| Invite, change roles, revoke | yes | no |
| Start, edit usage, cancel procedure | yes | yes |
| Create, edit, delete templates | yes | no |
| Read inventory and product detail | yes | yes |
| Count stock, adjust with reason | yes | yes |
| Add expiry, edit batch | yes | yes |
| Open a new bottle, Finished | yes | yes |
| Add to To buy, change quantity | yes | yes |
| Mark as ordered | yes | no |
| Receive delivery (invoice or manual) | yes | no |
| Create, edit, delete products | yes | no |
| Mark disposed | yes | no |
| Clinic settings, billing, CSV export | yes | no |
| View team | yes | read-only |

- Storage buckets `invoices` and `logos`: path prefix `clinic_id/`, policies by membership; invoices readable by admins only.
- A clinic must always have at least one active Admin (trigger on memberships).

### Acceptance criteria
- [ ] SQL tests with two clinics and an admin and a staff user per clinic prove: no cross-clinic reads; each "no" cell above fails for Staff with a clear error; the last Admin cannot be demoted or removed.

## MS-106 · Build the stock transaction engine
meta: milestone=M0; priority=P0; type=tech; area=platform; size=8; frames=f13,f14,f18,f20,f23,f27; screens=; prd=§1, §4 Transaction, §5, §9 Concurrency; depends=MS-104,MS-105

### Goal
One place where stock changes happen: Postgres functions that are atomic, write the ledger, keep batches and open items consistent, refresh statuses and alerts, and support Undo. Every feature ticket calls these; none writes stock tables directly.

### Functions (all `security definer`, check membership + permission + `clinic_can_write`, take an `idempotency_key uuid` and return the `action_id`)
- `stock_receive(clinic, lines jsonb, ref)` lines: product_id, qty_counted_units, unit_cost, lot, expiry_month. Creates or adds to the matching batch (same product + expiry_month + lot), updates `last_unit_cost`, type receiving.
- `stock_procedure_start(clinic, template_id, name, items jsonb, take_new product_ids[])` deducts countables (D9 FEFO), opens one unit per take-new product (deduct 1 from batches FEFO, insert open_item with `opened_in_event_id`), records the event. Negative allowed.
- `stock_procedure_edit(event_id, items jsonb, take_new[])` writes only the differences (type procedure, ref "Edited usage").
- `stock_procedure_cancel(event_id, note)` note required; returns every countable to the batches it came from (use the original transaction batch_ids), reverses openings whose open_item is still open (delete open item, +1 to its batch); if a bottle was already Finished it stays finished. Type cancellation.
- `stock_count_apply(clinic, counts jsonb)` counts: product_id, counted (unopened only for multi-use). One count transaction per changed product, reason "Physical count".
- `stock_adjust(product_id, actual_qty, reason, note)` reasons: Physical count, Expired, Damaged, Waste, Missing, Returned, Data correction, Other.
- `stock_dispose(batch_id, qty)` reason Expired, type disposal. Admin only.
- `batch_upsert(product_id, batch_id null, expiry_month, qty, lot)` used by Add expiry / Edit batch. Adding expiry to undated stock moves quantity from the undated batch into a dated one (no net change); editing a quantity writes an adjustment with reason Data correction.
- `bottle_open(product_id)` and `bottle_finish(open_item_id)`.
- `undo_action(action_id)` writes reversal rows (reverses_id set) for an adjustment, invoice receive, disposal or To buy add; only the same user, within 10 s (D10).

### After every change (same transaction)
`refresh_product(product_id)`: recompute status (MS-107), open or resolve alerts, and auto-add or update To buy (MS-128 rules: add when Low or Out of stock and no item in to_buy or ordered; recompute qty = target − current while status is to_buy and qty_edited is false).

### Concurrency
Row-lock the product (`select … for update`) inside each function so two assistants opening bottles at once both succeed with correct counts. Idempotency key unique per clinic so a retried request is a no-op returning the first result.

### Acceptance criteria
- [ ] SQL tests for each function: ledger rows, batch math with FEFO, negative stock on the undated batch, idempotent retry, cancel returns to original batches, undo window, permission failures.
- [ ] Two concurrent `bottle_open` calls on a product with 2 unopened leave 0 unopened and 2 open items.
- [ ] Each function runs under 100 ms on a 500-product seed (performance target: Start procedure < 1 s end to end).

## MS-107 · Compute product status, attention counts and values
meta: milestone=M0; priority=P0; type=tech; area=alerts; size=3; frames=f6,f16,f19,f20,f27; screens=; prd=§5 Status and alert rules; depends=MS-104,MS-106

### Rules (PRD §5)
| Status | Rule | Color |
|---|---|---|
| Out of stock | quantity ≤ 0 (multi-use: no unopened and no open) | danger |
| Low | quantity ≤ minimum (multi-use: unopened ≤ minimum, G3) | warning |
| Expiring | any batch with qty > 0 expires within the clinic's largest threshold | warning (≤ 30 days renders danger text, 31–90 warning) |
| Missing expiry | some quantity has no expiry date | info |
| Healthy | none of the above | success |

One badge per product, priority Out of stock › Low › Expiring › Missing expiry › Healthy. Expiry month means the batch expires on the last day of that month; "days left" = last day of month − today in the clinic time zone.

### Scope
- SQL view `product_status` (product_id, status, quantity, unopened, open_count, days_to_soonest_expiry, value = quantity × last_unit_cost).
- SQL view `clinic_attention` (to_buy_count, expiring_batch_count within window, missing_expiry_product_count, inventory_value, value_at_risk_90).
- Alert rows (MS-106 refresh) for Out of stock, Low, Expiring (per threshold crossed), Missing expiry, Invoice ready. Alerts resolve automatically when the condition clears.
- Daily cron (pg_cron, 03:00 clinic time is fine as UTC 07:00 for V1.1) re-evaluates expiry thresholds because time passing changes status without any transaction.
- Swift mirror `Core/Domain/ProductStatus.swift` (`static func evaluate(...)`) with the same rules for immediate UI updates after a change, covered by the same test table.

### Acceptance criteria
- [ ] A test table of at least 12 cases (countable, multi-use, negative, undated, expired batch, threshold sets) passes in both SQL (pgTAP) and Swift Testing.
- [ ] Cron run flips a product to Expiring when its batch enters the window and opens one alert.

## MS-108 · Handle errors, offline writes and double taps the same way everywhere
meta: milestone=M0; priority=P1; type=tech; area=platform; size=3; frames=; screens=; prd=§7 Errors, §9; depends=MS-103,MS-106,MS-154

### Scope
- Reads: repositories return fresh data; view models reload on `.task`, on pull-to-refresh (`.refreshable`) and when the app returns to the foreground (`scenePhase`). A small `ResponseCache` (Codable JSON files in the Caches directory, keyed by repository method + clinic id) lets screens show the last data while offline.
- Writes: every stock RPC goes through `RPCClient` with an idempotency key (MS-154). Primary buttons show `isLoading` and ignore taps until the call returns (view model flag, not a debounce timer).
- Offline: `PendingWriteQueue` (`@Observable`, persisted as JSON in Application Support) stores writes made while `NetworkMonitoring` reports offline, shows the banner "You're offline. Changes will sync." and replays them in order with the same idempotency key when back online. If a replay fails, toast "Couldn't save. Try again." and keep the user's input where the screen still exists.
- Field errors inline under the field in danger text. Save failures: toast "Couldn't save. Try again." keeping input.
- Crash and error reporting: Sentry Cocoa SDK via SPM (`sentry-cocoa`), started in `MediSaveApp`, with breadcrumbs for failed RPCs. Never attach user-entered text, names, emails or invoice contents.

### Acceptance criteria
- [ ] Double-tapping Start procedure creates one event (unit test with a delayed `FakeRPCClient`).
- [ ] With the network off (`FakeNetworkMonitor`), adjusting a quantity shows the banner, queues one write, and replays it once when the network returns.
- [ ] Queue survives an app relaunch.

## MS-109 · Seed a demo clinic that matches the design
meta: milestone=M0; priority=P1; type=chore; area=platform; size=2; frames=f6,f11,f16,f25,f27; screens=; prd=; depends=MS-106

### Goal
Local dev, previews and pilot demos open on the same data the frames show, so screens can be compared with `design/frames/*.png` line by line.

### Scope
`supabase/seed-demo.sql` (calling the RPCs so the ledger is consistent) creating clinic "Smile Dental" (Toronto, Canada, CAD), admins Sarah Mitchell (sarah@smiledental.ca) and Dr. Daniel Kim (daniel@smiledental.ca), staff Michael Reyes (michael@smiledental.ca), and Priya invited as Staff (priya@smiledental.ca, invited Oct 1) as in `design/frames/f31.png`, and the 20 products, 5 templates (Root canal, Cleaning, Filling, Crown, Extraction), 3 past procedures, To buy items, invoice lines and activity rows exactly as defined in the prototype constructor: `design/project/MediSave Mobile.dc.html`, the `const P = [...]`, `this.T = [...]`, `events`, `lines`, `orders`, `expiring` blocks. Products referenced by templates but missing from P (Needle 27g short, Paper points, Prophy angle, Patient bib, Matrix band, Microbrushes, Retraction cord, Gauze, Suture) are created as countable with sensible stock.
Prototype `mode` maps: Unit → countable, Package → countable with pack_unit/pack_size, Container → multi_use.

### Acceptance criteria
- [ ] `make db-reset seed-demo` produces a Home matching `design/frames/f6.png` numbers (3 To buy, 2 Expiring soon, 1 Missing expiry; values may differ by rounding).
