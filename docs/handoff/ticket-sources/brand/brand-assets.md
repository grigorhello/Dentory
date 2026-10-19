# Brand · Visual identity (outside the build order)

Tickets for the brand export of 2026-10-19 (`design/brand/`, see its README). They are not in `docs/BUILD-ORDER.md`: the build thread does not pick them up until Grigor asks, except MS-158, which he asked for first. `build_brand.py` turns this file into the issue bodies.

## MS-158 · App icon from the brand package
meta: milestone=M0; priority=P1; type=chore; area=platform; size=1; dod=ios; depends=MS-101; assets=design/brand/ios/AppIcon.appiconset/AppIcon-1024.png,design/brand/ios/AppIcon.appiconset/AppIcon-1024-dark.png,design/brand/ios/AppIcon.appiconset/AppIcon-1024-tinted.png,design/brand/ios/AppIcon.appiconset/Contents.json,design/brand/ios/dentory-app-store-1024.png

### Why
The app still has the empty `AppIcon` set from MS-101: a blank tile on the home screen. The brand export brings the icon in the three appearances iOS 18 offers (light, dark, tinted) in the single-size format Xcode 15+ expects for an iOS 17+ target. Grigor asked for this one first (2026-10-19).

### Scope
1. Replace the contents of `Dentory/Resources/Assets.xcassets/AppIcon.appiconset/` with the four files of `design/brand/ios/AppIcon.appiconset/`: `AppIcon-1024.png` (light, RGB, no alpha), `AppIcon-1024-dark.png` (blue tooth on transparent; the system adds the dark backing), `AppIcon-1024-tinted.png` (white tooth on transparent, greyscale; the system tints it) and `Contents.json` (idiom `universal`, platform `ios`, size 1024x1024, `luminosity` appearances `dark` and `tinted`). No per-size slots: the deployment target is iOS 17 and Xcode renders every size from the 1024 image. `ASSETCATALOG_COMPILER_APPICON_NAME` stays `AppIcon` in `project.yml`.
2. `design/brand/` stays the source of truth; the catalog holds a copy. When the design changes, copy again.
3. `make project build WARNINGS_AS_ERRORS=YES`: actool must accept the light icon (an alpha channel there is an error) and the two appearance variants (transparency there is expected).
4. Simulator check on iPhone 16 and iPad Pro 11-inch (M4): the blue tooth shows on the home screen under the name Dentory. On iOS 18, Home Screen customisation (long-press, Edit, Customize) set to Dark and to Tinted shows the dark and the tinted variant.
5. Nothing to do for App Store Connect now: MS-152 uploads `design/brand/ios/dentory-app-store-1024.png` (same pixels as the light icon, square corners, no alpha).

### Out of scope
The launch screen (MS-160), the mark and the wordmark inside the app (MS-159), the icon on the landing page and in emails (MS-161, MS-162), `AppIcon-AllSizes.appiconset` (legacy sizes, not needed on iOS 17+).

### Acceptance criteria
- [ ] `make project build WARNINGS_AS_ERRORS=YES` is green locally and CI is green on the pull request.
- [ ] `AppIcon.appiconset/Contents.json` lists exactly three images, all `1024x1024`, `universal`, `ios`: one without appearances, one `luminosity` `dark`, one `luminosity` `tinted`; the light PNG has no alpha channel (`file` says `8-bit/color RGB`).
- [ ] The PR shows the icon on the iPhone 16 simulator home screen (light, dark and tinted appearance where the simulator runtime allows) next to `design/brand/ios/AppIcon.appiconset/AppIcon-1024.png`.
- [ ] Nothing else in `Assets.xcassets` changes.

## MS-159 · Brand mark and wordmark in the app
meta: milestone=M2; priority=P2; type=feature; area=product; size=2; dod=ios; frames=f1; screens=signin; prd=§1; depends=MS-102,MS-110,MS-158; assets=design/brand/logo/dentory-lockup.png,design/brand/logo/dentory-lockup.svg,design/brand/logo/dentory-lockup-reversed.png,design/brand/logo/dentory-lockup-reversed.svg,design/brand/logo/dentory-mark.png,design/brand/logo/dentory-mark.svg,design/brand/logo/dentory-mark-cream.svg,design/brand/logo/dentory-wordmark.svg

### Why
The sign-in screen (f1) sets "Dentory" in plain Outfit type because no logo existed when it was built (MS-100 D15). The lockup, the mark and the wordmark exist now (D17). Where the brand shows inside the app is a product call, so this ticket is the proposal and stays in Backlog until Grigor says which screens get it.

### Proposed scope
1. **Asset catalog.** `Dentory/Resources/Assets.xcassets/Brand/` with three image sets from `design/brand/logo/`: `brand-mark` (`dentory-mark.svg`), `brand-lockup` (`dentory-lockup.svg`) and `brand-lockup-reversed` (`dentory-lockup-reversed.svg`). Single-scale, `"preserves-vector-representation": true`, rendering mode original (not template: the colours are the brand's). XcodeGen picks the folder up with the rest of `Dentory/`.
2. **Design-system component.** `Dentory/Core/DesignSystem/Components/MSLogo.swift`: `MSLogo(.lockup, height: 32)`, `MSLogo(.lockupReversed, height: 32)` and `MSLogo(.mark, size: 24)`. The component owns the brand rules: clear space of half the tooth's height as padding, minimum lockup width 96 pt, no tinting, no shadow. Accessibility label "Dentory"; `.accessibilityAddTraits(.isHeader)` when it replaces a heading. A Brand section in the hidden design-system catalog shows the three on cream and on ink.
3. **Sign in (f1).** Replace the `Text("Dentory")` heading in `Features/Auth/SignInView.swift` with the lockup at 40 pt height, left-aligned where the heading sits; "Sign in to your clinic." stays underneath. The frame still shows the plain wordmark; D15 lets the name win over the frame and D17 lets the lockup win over the plain name. Keep every `signin.*` element id.
4. **Other screens.** Only where the frame carries the product name: check Admin sign-up step 1 (f2) and Accept invitation (f5). Home, the tab bar and Account stay as drawn; the brand is not a decoration.
5. The reversed lockup is for the ink surfaces (featured cards, the dark offer band on the landing page); in V1.1 no app screen needs it, so the asset is added and shown in the catalog only.

### Out of scope
The app icon (MS-158), the launch screen (MS-160), the landing page and emails (MS-161, MS-162), any animation of the mark, a new colour for the brand (blue, cream and ink are the existing tokens).

### Acceptance criteria
- [ ] Simulator screenshots of f1 on iPhone 16 and iPad Pro 11-inch (M4) next to the frame; the lockup is crisp at 2x and 3x (vector) and respects the clear space.
- [ ] VoiceOver reads "Dentory, heading" on the sign-in screen; `signin.email`, `signin.password`, `signin.submit`, `signin.forgot` and `signin.signUp` are unchanged.
- [ ] The catalog's Brand section shows the lockup, the reversed lockup and the mark; `make lint` finds no raw colour (the SVGs carry their own).
- [ ] `grep -rn 'Text("Dentory")' Dentory/` lists no heading that the frame draws as a wordmark.

## MS-160 · Launch screen with the mark on cream
meta: milestone=M2; priority=P2; type=feature; area=platform; size=1; dod=ios; depends=MS-101,MS-158; assets=design/brand/logo/dentory-mark.png,design/brand/logo/dentory-mark.svg

### Why
`project.yml` sets `INFOPLIST_KEY_UILaunchScreen_Generation: YES`, so the app launches on a blank system-coloured screen (white in light mode, black in dark mode) and then cuts to the cream sign-in screen. MS-152 already planned a launch screen in cream; with the mark available the launch screen can be the brand's: cream background, the tooth centred, nothing else (Apple asks for no text on launch screens).

### Scope
1. **Info.plist.** Add to `Dentory/Resources/Info.plist` a `UILaunchScreen` dictionary with `UIColorName` = `LaunchBackground`, `UIImageName` = `LaunchMark` and `UIImageRespectsSafeAreaInsets` = true. Remove `INFOPLIST_KEY_UILaunchScreen_Generation` from `project.yml` so the generated plist does not carry a second, empty `UILaunchScreen`; verify with `plutil -p` on the built `Dentory.app/Info.plist` that the dictionary has the two names.
2. **Asset catalog.** `LaunchBackground.colorset` = canvas `#FFFEFB` (`Colors/canvas` has the value; the launch screen needs its own named colour because `UIColorName` must name a top-level colour set) and `LaunchMark.imageset` from `design/brand/logo/dentory-mark.svg` with `"preserves-vector-representation": true`, or 2x and 3x PNGs rendered at 96 × 109 pt if the vector does not render on the launch screen of the oldest supported runtime (iOS 17.0 simulator). The mark is blue; the app is light-only (MS-102 colour sets have one appearance), so cream in both appearances. If a dark appearance ever comes, the dark launch screen is ink with the cream mark (`dentory-mark-cream.svg`).
3. **Size.** The tooth at 96 pt wide, centred; no wordmark, no text, no version number.
4. **Verify** a cold launch on iPhone 16 and iPad Pro 11-inch (M4) (`xcrun simctl terminate booted ca.dentory.app`, then launch): cream with the mark, then the sign-in screen with no flash of white or black. Screenshots in the PR.

### Out of scope
Any splash animation or wordmark on launch (Apple discourages both), the app icon (MS-158), the in-app lockup (MS-159).

### Acceptance criteria
- [ ] Cold launch shows the mark on cream on both simulators; `plutil -p` of the built `Info.plist` shows `UILaunchScreen` with `UIColorName` `LaunchBackground` and `UIImageName` `LaunchMark`.
- [ ] No blank white or black frame before the sign-in screen in light or dark system appearance.
- [ ] `make project build WARNINGS_AS_ERRORS=YES` and `make uitest` green; CI green.

## MS-161 · Landing page dentory.ca with the brand
meta: milestone=M2; priority=P1; type=feature; area=product; size=2; dod=web; depends=MS-157; assets=design/brand/logo/dentory-lockup.png,design/brand/logo/dentory-lockup.svg,design/brand/logo/dentory-lockup-reversed.png,design/brand/logo/dentory-lockup-reversed.svg,design/brand/web/favicon.svg,design/brand/web/icon-192.png,design/brand/web/apple-touch-icon.png,design/brand/web/maskable-512.png,design/brand/web/favicon.ico,design/brand/web/site.webmanifest,design/brand/logo/dentory-icon-rounded.png

### Why
The landing page exists: `site/` (index, one-pager for print, privacy, support) from the marketing thread's PR #137, published by `.github/workflows/pages.yml` to GitHub Pages on every push to the default branch. It was built before the brand existed: the header is the word "Dentory" in Outfit, its blue is `#2457f5` and its ink `#1c1b1a` (not the product's `#1A63D6` and `#201515`), and it has no favicon. Grigor owns `dentory.ca` (bought 2026-10-17) and will ask for the page when he wants it; this ticket is that brief. It restyles the page with the real brand and puts it on the domain. It does not rebuild the site.

### Scope
1. **Brand files on the site.** Copy `design/brand/web/*` to the root of `site/` (`favicon.ico`, `favicon.svg`, `favicon-16.png`, `favicon-32.png`, `apple-touch-icon.png`, `icon-192.png`, `icon-512.png`, `maskable-512.png`, `site.webmanifest`) and `design/brand/logo/dentory-lockup.svg`, `dentory-lockup-reversed.svg`, `dentory-lockup.png`, `dentory-lockup-reversed.png` to `site/brand/`. The PNG lockups are what the emails of MS-162 link to, so they must stay at `https://dentory.ca/brand/…` once published.
2. **Head of every page** (`index.html`, `one-pager.html`, `privacy.html`, `support.html`): the four lines from `design/brand/README.md` (`favicon.ico` with `sizes="any"`, `favicon.svg`, `apple-touch-icon`, `manifest`), `<meta name="theme-color" content="#1A63D6">`, and `og:title`, `og:description`, `og:image` for link previews. Use paths relative to the page (`favicon.ico`, not `/favicon.ico`) so the site also works at `grigorhello.github.io/Dentory/` before the custom domain is live; add `"start_url": "./"` to the manifest for the same reason.
3. **Header and footer.** The header shows the lockup (`brand/dentory-lockup.svg`, 32 px high, `alt="Dentory"`, linking to the top) instead of the text; the dark offer band and the footer use the reversed lockup at 28 px. Clear space of half the tooth's height around the lockup; nothing else changes in the layout.
4. **Colours.** `:root` of each page: `--blue:#1a63d6`, `--page:#fffefb`, `--ink:#201515`, `--card:#f8f4f0`, `--line:#e6e1d6`, `--muted` a warm grey from the design system (`inkMid` or `inkSoft` in `Dentory/Resources/Assets.xcassets/Colors`), hover one step darker (`primaryHover`). Buttons keep the 12 px radius, Outfit stays the display font (loaded from Google Fonts; the lockup is outlined so it needs no font).
5. **One-pager.** `one-pager.html` prints the lockup in its header at 40 px and keeps letter size.
6. **Domain.** Add `site/CNAME` containing `dentory.ca`. In GitHub, Settings, Pages: source GitHub Actions (already), custom domain `dentory.ca`, Enforce HTTPS once the certificate is issued. DNS at the registrar (Grigor, listed in MS-157): four `A` records on the apex to GitHub Pages (`185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`) and a `CNAME` for `www` to `grigorhello.github.io`. The page is reachable on the github.io address until then.
7. **Screenshots.** The four images in `site/img/` are cropped design frames; replace `home.png` with a capture of the shipped Home (MS-114) at the same crop, and the others as their screens ship. Leave the rest as it is.
8. **Placeholders** stay Grigor's and the marketing thread's: `VIDEO_LINK`, `FORM_ACTION`, `EMAIL`, `PHONE`, `DATE`, `SIGNUP_LINK` (listed in `site/README.md`). Copy changes belong to the marketing thread, not to this ticket.

### Out of scope
New sections or copy, a blog, analytics, a form backend, an `og:image` card at 1200 × 630 (the export has none; compose one from the lockup on cream only if Grigor asks), the app's own screens.

### Acceptance criteria
- [ ] Every page shows the lockup in the header, the favicon in the tab (Safari, Chrome, iOS home screen bookmark) and the brand colours; the mobile layout of PR #137 is unchanged at 390 px wide.
- [ ] `site/site.webmanifest`, `site/CNAME` and `site/brand/dentory-lockup.png` are published; `https://dentory.ca/brand/dentory-lockup.png` returns the image once DNS points at GitHub Pages (until then the github.io address does).
- [ ] The Pages workflow is green; Lighthouse on the published page reports no missing favicon or manifest error.
- [ ] The one-pager prints with the lockup on one letter page.

## MS-162 · Brand in emails and link pages
meta: milestone=M2; priority=P2; type=feature; area=platform; size=1; dod=none; depends=MS-112,MS-113,MS-161; assets=design/brand/logo/dentory-lockup.png,design/brand/logo/dentory-lockup-reversed.png,design/brand/logo/dentory-lockup.svg

### Why
Every email Dentory sends and every web page a link falls back to shows the name in plain type: the invitation email and the universal-link fallback page of MS-112 (`supabase/functions/_shared/invitation-email.ts`, `applinks/invite/index.html`), the password-reset email of MS-113, the billing emails of MS-141 and the weekly digest of MS-145. With the lockup hosted on `dentory.ca` (MS-161) they can carry the brand. Emails need an absolute https image URL; a link page can inline the SVG.

### Scope
1. **Email layout.** One shared header and footer in `supabase/functions/_shared/email.ts` (from MS-112), used by every function that sends mail: cream background `#FFFEFB`, the lockup as `<img src="https://dentory.ca/brand/dentory-lockup.png" width="140" height="31" alt="Dentory">` at the top, ink text, one blue button, and a footer in ink with the reversed lockup at 112 px wide. Width and height attributes set so the layout holds while images load; `alt="Dentory"` so clients that block images still show the name. No tracking pixel, no external CSS, no web fonts (system sans-serif; the wordmark is in the image).
2. **Supabase Auth templates.** The hosted project's email templates (confirm sign-up, reset password, magic link if ever used) get the same header and footer in the dashboard (Authentication, Email templates); keep a copy of each template under `supabase/templates/` so the dashboard can be restored.
3. **Link pages.** `applinks/invite/index.html` and any later fallback page inline `design/brand/logo/dentory-lockup.svg` (no network dependency on the landing page), the favicon lines of MS-161, cream background, ink text, the one blue button.
4. **Existing tickets** reference this one: MS-113, MS-141 and MS-145 use the shared layout instead of their own markup.

### Out of scope
Marketing newsletters, the landing page (MS-161), push notification icons (APNs uses the app icon), the content of any email.

### Acceptance criteria
- [ ] The invitation email rendered in Resend's preview, Apple Mail and Gmail shows the lockup at the top and the reversed lockup in the footer; with images blocked the word "Dentory" appears in their place.
- [ ] `applinks/invite/index.html` shows the inline lockup with no request to the landing page; the favicon shows in the tab.
- [ ] `make functions-check` is green; the templates copied under `supabase/templates/` match the dashboard.
