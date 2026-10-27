# Pilot audit: frames f01 to f38 and copy (MS-136)

The visual comparison and the copy check of MS-136 (#107), run on 2026-10-26 at commit c510b5b (after MS-131, #203) with the `-uiTesting` demo doubles (Smile Dental, clock Friday Oct 2, 2026 9:41), Admin and Staff, on iPhone 16 Pro iOS 18.4 (402 pt, the frames' width), iPhone SE (3rd gen) iOS 18.4, iPad Pro 11-inch (M4) iOS 18.4 and iPhone 17 iOS 26.3. The ticket asks for a bug for each visible difference; this file is that list, each finding with its status. The screenshots and the side-by-side composites (frame left, app right) the evidence names refer to were kept out of the repository.

A difference is listed only when MS-100 (#71), `decisions-log.md` or a merged PR's note does not cover it. Where frame and PRD disagree, MS-100 D2: the frame wins for layout and copy, the PRD for business rules.

Totals: no P0. Visual P1 4, P2 14. Copy P2 5. No exclamation mark, emoji or "please" in any user-visible string.

## Status

| Status | Meaning |
|---|---|
| Fixed in fixes 1 | The first fixes PR, "MS-136 · Pilot audit fixes: light mode, contrast, sign-up keyboard, copy" (`Refs #107`). |
| Fixed in fixes 2 | The second fixes PR, "MS-136 · Pilot audit fixes 2: type, chips, badges, icons, iPad column" (`Refs #107`). |
| Kept by decision | The PRD or the ticket wins over the frame (decisions log, 2026-10-26 17:00). |
| Open | No fix or decision yet. |

| Finding | Status |
|---|---|
| V-01 Dark Mode | Fixed in fixes 1 |
| V-02 Pinned search, segments and chips | Fixed in #206 (MS-103 fix) |
| V-03 Tab bar and captions lighter than the frames | Fixed in fixes 1 (f22's option chevrons: see V-08) |
| V-04 Sign-up step 1 under the keyboard | Fixed in fixes 1; all three fields above Continue where they fit: fixes 2 |
| V-05 Pushed titles | Fixed in fixes 2 |
| V-06 Header heights | Fixed in fixes 2 |
| V-07 Home tiles and Latest name | Fixed in fixes 2 |
| V-08 Text and icon sizes | Fixed in fixes 2 |
| V-09 Filter chips | Fixed in fixes 2 |
| V-10 Status badge size | Fixed in fixes 2 |
| V-11 Three icons | Count stock: kept by decision; Send invitations and the logo placeholder: fixed in fixes 2 |
| V-12 Sign-in and sign-up details | Fixed in fixes 1; the password hint while too short: fixes 2 |
| V-13 Cancel procedure in red | Kept by decision |
| V-14 Time zone truncated | Fixed in fixes 1 |
| V-15 iPad column and tabs | Fixed in fixes 2 |
| V-16 A caption line starting with "·" | Fixed in fixes 1; one shared separator, also inside typed text: fixes 2 |
| V-17 Narrow phone and keyboard | "cartridges" and the sign-up status bar: fixed in fixes 1; the context line: fixed in fixes 2; the rows left with the keyboard up: open |
| V-18 Password show/hide eye | Kept by decision |
| C-01 Database refusals verbatim | Fixed in fixes 1 |
| C-02 "Open a new bottle" with the unit | Kept by decision |
| C-03 Captions over 60 characters | Fixed in fixes 1 (the builders' own wording) |
| C-04 Internal wording that ships | Fixed in fixes 1 |
| C-05 Password reset email | Fixed in fixes 1 (the hosted template takes the new file) |
| iOS 26 Save Password? sheet in XCUITest | Fixed in fixes 1 |
| Large text beyond the PRD's Large step | Fixed in fixes 2 |

## P1

**V-01 Dark Mode is not handled.** No frame is dark. With the phone set to Dark the page stays cream (fixed asset colours) while system controls draw dark on it: the month and year wheels (Receive manually f24, Add expiry, Edit batch, the invoice line Expiry f23/f38) print white on cream and are unreadable; menus (Adjust reason, Clinic settings expiry warning f33) are dark slabs; the Team action sheet (f31) is black. Same on iOS 26.3. "V1.1 is light only" existed only as a comment (`Dentory/Core/DesignSystem/Tokens/MSColor.swift`); nothing opted out (no `UIUserInterfaceStyle`, `preferredColorScheme` or `overrideUserInterfaceStyle`). `docs/handoff/ticket-sources/brand/brand-assets.md` notes the launch screen is black in dark mode. Evidence: `shots/pro-once-wheels-dark.png`, `pro-once-batch-wheels-dark.png`, `cmp/wheels-sys.png`, `shots/pro-dark-settings-menu.png`, `pro-dark-adjust-reason-menu.png`, `pro-dark-team-menu.png`, `cmp/dark-b.png`, `cmp/dark-d.png`, `cmp/ios26-wheels-light-vs-dark.png`.
Status: fixed in fixes 1. `INFOPLIST_KEY_UIUserInterfaceStyle: Light` in `project.yml`: the whole app is light, the system's controls included.

**V-02 Search, segments and chips do not pin when the list scrolls.** f09-2 (Activity History), f16-2/3 (Inventory Admin), f17-2/3 (Staff), f18-2 to f18-5 (Count stock). Known issue in build-state (PR #172 note), blockers #166 and #195 merged. Evidence: `cmp/f16-2.png`, `f16-3.png`, `f17-2.png`, `f17-3.png`, `f18-2.png`, `f18-3.png`, `f18-5.png`, `f09-2.png`.
Status: fixed in #206, "MS-103 fix · Search, segments and chips stay pinned under the title".

**V-03 Tab bar and sentence captions lighter than the frames, below PRD §7's 4.5:1.** Frames draw text-body #605d52 (6.5:1 on #fffefb, 6.0:1 on #f8f4f0) and a cream-soft tab bar (#f8f4f0) with inactive label and icon #605d52. The app drew text-secondary #939084 (3.17:1 on #fffefb, 2.92:1 on #f8f4f0) and a cream tab bar. Places: the tab bar on every tab frame and the iPad frames; sub-titles on f01, f02, f05; Home's Receive delivery caption (f06); f13's summary line; f20/f21's "System estimate" and "54 of 54 tracked" lines; f23's "Resolve every line to continue."; f35's empty text; chevrons on f10, f10-2, f11 history rows (frame #656257 vs app #b8b4ab) and f22 option cards (#382d2d vs #807876). Code: `Dentory/Core/Navigation/AppTabBar.swift`, `Dentory/Features/Auth/SignInView.swift`, `Dentory/Features/Onboarding/OnboardingView.swift`, `Dentory/Features/Invitation/AcceptInvitationView.swift`, `Dentory/Features/Home/HomeView.swift`, `Dentory/Features/ProductDetail/ProductQuantityCard.swift`. The #939084 token itself is below 4.5:1 but the frames use it for list captions, badges and placeholders, which match and are not listed. Evidence: `cmp/f06.png`, `f01-empty.png`, `f02.png`, `f13.png`, `f20.png`, `f22.png`, `f23.png`, `f35.png`, `f11.png`, `f10-2.png`, `shots/pro-f06-home-admin.png`.
Status: fixed in fixes 1, following the frames: the tab bar is cream-soft with its inactive items in body text, and the listed captions and chevrons take the body text token (f01's "Setting up a new clinic?" too, which f1 draws in body text); the secondary token is unchanged where the frames use it. f22's option chevrons were already ink: they read lighter because the app's chevron is a thinner 20 pt Lucide stroke, which is V-08's icon sizes.

**V-04 Admin sign-up step 1: the pinned Continue bar covers the Password field with the keyboard up.** f02. On the Pro the Password field was fully behind the bar while Full name or Work email had focus and half behind it when focused; on the SE the focused Work email was half behind it. Return on Full name and Work email did not move on (Sign in and Join chain fields with `.submitLabel(.next)`/`.onSubmit`; `OnboardingView` had no focus state). On iOS 26.3 the Password field was not hittable with the keyboard up (field y 488-508 pt, bar y 483-531 pt). Steps 2 and 3 are fine. First-run path of every new clinic. Evidence: `shots/pro-kb-signup1-email.png`, `pro-kb-signup1-password.png`, `se-kb-signup1-email.png`, `ios26-probe-carryB-before-continue.png`, `cmp/pro-kb-1.png`, `se-kb-1.png`, `pro-kb-2.png`.
Status: fixed in fixes 1. Return moves through the three fields and continues from Password; as the focus moves and the keyboard takes its room, the field after the focused one is scrolled clear of the bar. Fixes 2 (#207 review): when all three fields fit above the bar, as on an iPhone SE, the last is scrolled to the bottom of the room, so all three stay in sight whichever has focus, Full name included (SE with the keyboard up: Full name at 139.5 pt, Password ending at 326, the bar from 338); a reveal still waiting is cancelled by the next (`OnboardingFieldsReveal`); `OnboardingUITests.testStepOneStaysAboveContinueWithTheKeyboardUp`, which fails with the fixes 1 reveal (Password ending at 409 pt under a bar at 338 on the SE).

## P2, visual

**V-05 Pushed screen titles 24 pt semibold; frames 20 pt bold.** Every pushed screen (f08-f10, f13-f15, f20-f24, f27-f35, f37, f38). Frame Inter 700 20 pt, tracking -0.5; app Inter 600 24 pt, tracking -0.6 (`Dentory/Core/Navigation/ScreenHeaders.swift`). PRD §7 says 24 px; D2 gives the frame priority; PR #138 notes no deviation. Evidence: `cmp/f13.png`, `f34.png`, `f27.png`.
Status: fixed in fixes 2. Pushed titles are Inter 700 20 pt with -0.5 tracking (`TextStyle.title20`), as is Product detail's name, which f20 draws as the screen's title in the content; sheet titles keep PRD §7's 24 pt, since no frame draws a sheet.

**V-06 Headers sit lower than drawn.** Root titles 17-21 pt lower (Procedures 70 vs 91, To buy 70 vs 87, Inventory 71 vs 91, Home clinic name 90 vs 107), pushed titles 7-8 pt lower (Billing 75 vs 82, Team 75.5 vs 83, Expiring soon 75 vs 82). The app uses the real safe area (59-62 pt) plus 16 pt where the frames use a 54 pt status area (PRD §7 "Status bar area 54px"). Costs about a row per screen. Evidence: `cmp/f11.png`, `f06.png`, `f13.png`, `f34.png`.
Status: fixed in fixes 2. Headers are placed from the real safe area where the frames draw them under their 54 pt status area: a root header 8 pt and a pushed header's row 6 pt under the status bar (`PageLayout.headerInset`). An iPhone with the Dynamic Island ends its safe area a few points under its 54 pt status bar, so a header adds only what is missing and never starts above the safe area. iPhone 16 Pro, frame then app: Procedures 70 and 71, Inventory 71 and 71.7, Home's clinic name 90 and 90.7, pushed titles 75-75.5 and 76-77 (the frames' pushed row starts 2 pt above that phone's safe area). A root title's small button no longer lowers it, and the banner and the pinned controls follow 12 pt apart, as f16 and f09 draw them (Inventory's search field 111 and 114.3, Activity's segments 121.5 and 122.7). An iPad keeps its headers 8 pt under its own 24 pt status bar, higher than f36 to f38, which keep the phone's status area.

**V-07 Home tiles and Latest name.** f06, f07, f36. Frame digits Outfit 500 48 pt (`display48` exists since PR #178), labels Inter 600 14, tiles 132 pt tall, Latest name Inter 600 16. App digits Outfit 500 32 (`Dentory/Features/Home/AttentionTile.swift`), labels Inter 400 16, tiles 152 pt, Latest name Inter 700 20 (`Dentory/Features/Home/ProcedureCard.swift`). Evidence: `cmp/f06.png`, `f07.png`, `f36-top.png`.
Status: fixed in fixes 2. Counts in Outfit 500 48 pt, labels in Inter 600 14, the three tiles as tall as the tallest (127 pt of straight edge, as f6) and 6 pt under their eyebrow; the Latest name in Inter 600 16. Inside a tile the count sits about 6 pt lower than drawn: iOS keeps the 48 pt figure's whole line box, which CSS trims to 48.

**V-08 Text and icon sizes beyond PR #128's row-text note.** List header rows (f13 "Supplies for this procedure / Qty", f14 "Supplies used / Used", f20 "Expires / Qty / Lot"): frame Inter 600 14, app Inter 400 16 (`Dentory/Core/DesignSystem/Components/ListCard.swift`). Quantity card (f20, f21): labels 14 vs 16 (`ProductQuantityCard.swift`); estimate line 14 pt on two lines vs 16 pt on three; "Tap a batch to edit its expiry, lot or quantity." 12 vs 14 (`ProductExpiryCard.swift`). Icons: (i) beside "Opened a new one?" (f13-2, f37) 22 vs 14.7 pt (`ProcedureBottlesSection.swift`); stepper minus/plus (f13, f15, f18, f25) 16 pt 2 pt stroke vs 12.7 pt ~1.3; remove X ~15 vs 13; template pencil (f11) ~21 vs 18; select chevron (f24, f33) 22 px #605d52 vs 16 px #939084 (PRD §7 asks 20 px Lucide 1.75 stroke); f22's option chevrons, a thinner stroke than drawn (V-03). Account rows (f29-f32) 49 pt apart vs 53. Evidence: `cmp/f13.png`, `f13-2.png`, `f20.png`, `f20-card.png`, `f14.png`, `f11.png`, `f29.png`, `f24.png`, `scratch/f13-stepper-cmp.png`.
Status: fixed in fixes 2. List header rows in Inter 600 14, 12 pt over and 8 pt under the line (f13, f14, f20); the quantity card's labels and lines and the expiry total in 14 pt, its unit in 12, "Tap a batch…" in Inter 500 12. The frames draw the icons the prototype places by hand at Lucide's own 24 pt with its default 2 pt stroke (the sizes and colours it asks for do not reach them; the design system's components draw theirs as asked, such as f33's 16 pt select chevron). The listed icons are now 24 pt: the stepper's − and + (f13, f15, f18, f25), a supply's remove X and the template pencil (`IconButtonSize.row`), the (i) 6 pt after "Opened a new one?" (f13-2, f37), Receive delivery's option chevrons (f22), and the Product select's chevron in body text (f24); Account's icons and chevrons too, which sets f29's 53 pt rows. Their stroke stays the icon set's 1.75 (PRD §7), 0.25 pt lighter than the frames. f33's selects already drew f33's 16 pt secondary chevron and keep it.

**V-09 Filter chips shape and weight.** f09, f09-2, f16-f19. Frame: 6 pt rounded rectangles, no border, Inter 600 14, ink fill when selected. App: capsules with a 1 pt border, Inter 400 14 (`Dentory/Core/DesignSystem/Components/FilterChip.swift`); the app's own `Radius.swift` says chips use 6 pt. Evidence: `cmp/f16.png`, `f19.png`, `f09.png`.
Status: fixed in fixes 2. Chips are 6 pt rounded rectangles without a border, Inter 600 14 with 12 pt sides, ink when selected and cream-soft otherwise.

**V-10 Inventory status badges larger than drawn.** f16, f17, f19. Frame: small badge (Inter 500 12, 8 pt padding; "Out of stock" ~85 pt). App: medium (Inter 600 14, 12 pt; ~106 pt) via `StatusBadge(badge)` in `ListRow.swift`; `StatusBadgeSize.small` exists (`StatusBadge.swift`). Tones are covered (PR #128, decisions-log 2026-10-26 06:00), size is not. Evidence: `cmp/f16.png`, `f19.png`.
Status: fixed in fixes 2. A list row's badge is the small one (`ListRow`'s `badge:`), which only Inventory's rows use.

**V-11 Three icons.** f16/f17 Count stock: frame calculator, app clipboard-list (`InventoryHeaderAction.swift`); PRD §6.4 and Appendix B say clipboard-list. f04 Send invitations: frame paper plane, app user-plus (`OnboardingView.swift`). f03 logo placeholder: frame picture, app camera (`LogoPickerLabel.swift`). The icon set has no calculator, send or image icon. Evidence: `cmp/f16-head.png`, `f04.png`, `f03.png`.
Status: Count stock keeps clipboard-list, kept by decision (MS-115's ticket and Appendix B over the frame); Send invitations and the logo placeholder: fixed in fixes 2, with Lucide's send and image added to the icon set (`Icon.send`, `Icon.image`) as the other icons were.

**V-12 Sign-in and sign-up details.** f02: title broke "Create your / admin account" where the frame breaks "Create your admin / account"; the title view was 221.7 pt wide in a 362 pt column (`onboard.title`). The password hint "At least 8 characters" showed under the field and again as placeholder (`OnboardingView.swift`); the frame has no hint (MS-111 asks for one). f01: "Forgot password" 16 pt semibold ~145 pt wide vs frame 14.4 pt bold ~120 pt (`SignInView.swift`). f04: Role select 140 pt wide vs 120 (`OnboardingView.swift`). Evidence: `cmp/f02.png`, `f02-title.png`, `f01-empty.png`, `f04.png`.
Status: fixed in fixes 1. The title keeps the frame's break on a phone (iOS moved "admin" down to avoid a lone last word) and stays on one line where it fits; the minimum shows once, as the placeholder, as f2 draws it; Forgot password is the small text button; the Role select is 120 pt. Fixes 2 (#207 review): while 1 to 7 characters are typed "At least 8 characters" shows under the password too, so a disabled Continue has its reason on screen; Join and Set a new password share the rule and do the same (`NewPassword`).

**V-13 f14: "Cancel procedure" red in the app, ink in the frame.** PRD §6.3 says danger text; PR #176 mentions the red as behaviour, not as a deviation. Evidence: `cmp/f14.png`.
Status: kept by decision (PRD §6.3's danger text over the frame).

**V-14 f33: time zone truncated** ("America/Toro…" in the half-width select; the frame shows "America/Toronto"). Evidence: `cmp/f33.png`, `shots/pro-f33-settings.png`.
Status: fixed in fixes 1. The Currency select is as narrow as the Role select (120 pt), so the time zone takes the rest of the row, and a select's value has one 8 pt gap before its chevron (there were two): every Canadian time zone reads whole on an iPhone SE.

**V-15 iPad (f36-f38): content column 40 pt narrower, tabs spread.** Frame content 720 pt with the four tabs clustered ~123 pt apart; app content 680 pt because the 720 pt cap includes the 20 pt side padding (`Dentory/Core/Navigation/ContentColumn.swift`), tabs 180 pt apart across the 720 pt bar (`AppTabBar.swift`). Evidence: `cmp/f36-top.png`, `f36-bot.png`, `f37-top.png`, `f38-top.png`, `shots/ipad-f36-home.png`.
Status: fixed in fixes 2. The content column is 720 pt inside the 20 pt gutter (`contentColumn()`), and so are the pinned bars, sheets and toasts: on the iPad Pro 11-inch the content runs from 57 to 777 pt, as f36. The tabs are at most 120 pt wide, 4 pt apart inside 8 pt sides, so they cluster as f36 to f38 draw them (Home's tab at f36's 215 to 247 pt) and sit 4 pt further in on a phone, as every frame draws them.

**V-16 A wrapped caption can start a line with "·".** f25 "Current 1 · target 5 / · Patterson"; SE Product detail history "· Michael"; large text Home "12 supplies / · Sarah". Evidence: `cmp/f25.png`, `shots/se-f20-product-admin-2.png`, `shots/ios26xxxl-f06-home-admin.png`.
Status: fixed in fixes 1. Every caption the app builds has a no-break space before each "·", the engine's own labels it shows included ("Undo · Damaged"); buttons and segments, which never wrap, keep the plain space. Fixes 2 (#207 review): one shared `Caption.separator` replaces the hand-written ones, and `Caption.joined` and `Caption.attached` keep the dots inside text people typed on their line too, such as a location "Operatory 1 · Drawer A" in Count stock.

**V-17 Narrow phone and keyboard (no frame).** SE: "cartridges" wrapped "cartridge / s" in Add expiry's How many (`shots/se-kb-batch-quantity.png`); Product detail's context line truncates (`shots/se-f20-product-admin.png`); keyboard up on Inventory leaves 1.5 rows on SE, 3 on Pro (`shots/se-kb-inventory-search.png`, `pro-kb-inventory-search.png`); the scrolled sign-up form passed under the status bar and Back overlapped the carrier text (`cmp/se-kb-1.png`).
Status: a text field's unit no longer wraps (the input gives way) and the status bar of sign-up and Join is painted the page colour: fixed in fixes 1. The context line takes a second line rather than lose its end: fixed in fixes 2. The rows left with the keyboard up: open.

**V-18 f01: the Password field has a show/hide eye the frame does not draw.** PRD Appendix B lists "Password field, show/hide toggle" (`signin.password`); PR #141 lists the toggle without noting the frame. Evidence: `cmp/f01.png`.
Status: kept by decision (PRD Appendix B over the frame).

## P2, copy

**C-01 Database refusal sentences reached people verbatim, lowercase, no full stop.** `Dentory/Core/Data/RPCClient.swift` mapped SQLSTATE 22023, 23514, 23505 to `AppError.validation(field:message:)`; `Dentory/Core/Data/AppError.swift` shows the message as toast or inline text. Stock engine sentences in `supabase/migrations/20261016150000_stock_engine.sql`: "the product is archived", "unknown product", "the procedure was cancelled", "the procedure was already cancelled", "a note is required to cancel", "a quantity cannot be negative", "a count cannot be negative", "unknown batch", "the disposed quantity must be between 0 and what the batch holds", "the expiry is a month", "only multi-use products are opened", "unknown open item", "the bottle is already finished", "this action cannot be undone", "already undone", "the undo window has passed", "nothing to receive", "a procedure needs a name". Reachable when two people act on the same thing or a screen is stale. Later migrations redefine some of these functions with the same sentences.
Status: fixed in fixes 1. `Dentory/Core/Data/ServerRefusal.swift` maps every refusal sentence the database or an Edge Function sends that is lowercase or needs other words to house copy, keyed by the server's own sentence, and gives any other its missing full stop; a constraint's own message reads "Couldn't save. Try again."; a unit test reads the migrations and fails on a sentence that would show without a capital.

**C-02 "Open a new bottle" changes with the unit.** `ProductDetailViewModel+Rows.swift` builds "Open a new bottle/syringe/kit"; `ProductDetailViewModel.swift` "Syringe opened", "Kit finished". PRD §7 lists "Open a new bottle"; the ticket asked for the unit in the label; no frame draws it.
Status: kept by decision (MS-120's ticket asks for the unit).

**C-03 Captions over 60 characters.** PRD or frame wording (kept): Procedures note (152, `ProceduresViewModel.swift`), invite step caption (95, `OnboardingView.swift`), "These are defaults. Staff can add or remove items for each procedure they perform." (82, `ProcedureEditViewModel+Copy.swift`). Builders' own wording: "Each invoice appears here once it is issued, and its receipt goes to your billing emails." (89, `Dentory/Features/Billing/InvoicesViewModel.swift`); "Nothing is added to inventory, and the invoice's photo or file is deleted." (74, `InvoiceViewModel+Copy.swift`); "To make changes, add a card from the link in your billing email." (64, `Dentory/Core/Navigation/ReadOnlySheet.swift`); "Couldn't load products. Close and reopen Add item to try again." (63, in four view models, plus two variants). The read-only Home notices (`Dentory/Features/Home/HomeNotice.swift`) are notices with two ideas each.
Status: the builders' own wording is fixed in fixes 1: "Each invoice appears here once it is issued.", "Nothing is added to inventory. The photo or file is deleted.", "To make changes, add a card from your billing email.", "Couldn't load products. Reopen Add item to try again." (Choose product and this sheet likewise). The PRD and frame wording and the notices stay.

**C-04 Internal wording that ships.** `Dentory/App/TabPlaceholderView.swift` read "{tab} arrives with its own ticket." Reachable only when the session was missing, but in Release.
Status: fixed in fixes 1. The tabs are handed the signed-in session, so every tab has its screen and the placeholder is gone.

**C-05 Password reset email: two ideas in one sentence.** `supabase/templates/recovery.html`: "The link works for 1 hour and only once. If you did not ask for this, you can ignore this email; your password stays as it is."
Status: fixed in fixes 1: "If you did not ask for this, you can ignore this email. Your password stays as it is." The hosted projects' Reset password template is the same file (build-state, open item 7).

## Cross-checks (not counted)

- iOS 26.3: custom-drawn screens identical to iOS 18.4; system sheets float as inset cards. A system "Save Password?" sheet appears when a password field leaves the screen and blocked XCUITest taps (`OnboardingUITests.testAdminSignUpLandsOnHome` failed at step 2 until "Not Now"). Status: fixed in fixes 1. XCTest's interruption monitors pass this sheet by, since it is the app's own; the flows that go on after a password answer it with Not Now (`DentoryUITests/XCUIApplication+SavePassword.swift`, shared with the end-to-end flows), and on iOS 18 that returns at once.
- Large text (XXXL, beyond the PRD's Large promise): To buy's segment labels run together ("Ordered · 5Received · 1"), the pinned bar label truncates ("Start procedure · 10 ite…"), Product detail's context line truncates, tab labels nearly touch (`cmp/xxxl-f25-tobuy-admin.png`, `xxxl-f13-adjust.png`, `xxxl-f20-product-admin.png`, `xxxl-f06-home-admin.png`). Status: fixed in fixes 2 (checked at XXXL on an iPhone 16 Pro, iOS 18.4): a segment keeps 4 pt on each side and shrinks to 60% before it would touch the next, a button label shrinks to 70% rather than lose its end, Product detail's context line takes a second line, and the tabs' labels keep their 4 pt apart on one line, shrinking to 70% if they must.
- The Debug-only "Shell demo" row on Home (`#if DEBUG` in `HomeView.swift`) must be absent from Release. It is compiled only in Debug.

## Covered differences (not findings)

No Google sign-in (D4, #141, #149); back chevron only on sign-up step 1 (#149); eyebrow weekday (#138); row text 14/12 (#128); alert dot colour, days to expiry and month precision (#175, #174, D8); History content (D5, #136, decisions-log 2026-10-26 08:45); Inventory value layout (#178); "+ Procedure" by role (#168); "+ Add item" and the Take new row (#170, #171, decisions-log 2026-10-19 20:45); Edit procedure minimum and Delete (#171); minus disabled at 0 (PRD §7); Inventory order, tones, "1 kit" (#151, #128, #174, decisions-log 2026-10-26 06:00); last-row lines (#179); Product detail badge and context line (#160); expiry card (#160, #164, D8); "Add to buy" for Staff (G2); Receive delivery copy and order (decisions-log 2026-10-23 22:00); Review invoice details (decisions-log 2026-10-26 06:00 and 08:45, #136); Receive manually labels (#197, decisions-log 2026-10-25 23:45); To buy counts and units (#136, #173); Account rows (#179); Clinic settings fields and Save (D14, #185); no Change on Payment method (D18); empty invoices text (decisions-log 2026-10-20 13:30); iPad bottom tab bar (#138).

## Frame coverage

All 52 frame images walked. Matching apart from systematic items (V-03, V-05, V-06) and covered differences: f05, f08, f12, f27, f28, f34. Not reached: password bullets in screenshots (a simulator capture limit), figures only in the real database, VisionKit scanner and Photos/Files pickers, push opening a screen, universal links, in-app Safari, VoiceOver, accessibility text sizes, emails rendered in a mail client, the Release build.
