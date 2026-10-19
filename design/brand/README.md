# Dentory brand assets

The visual identity of Dentory, delivered by Grigor on 2026-10-19 as the export "Mobile app design for MediSave" (the file carries the old product name; everything inside says Dentory). This folder is the only place the brand files live in the repository; `export-README.md` is the designer's own note, kept verbatim. The source zip stays out of git.

Until this export there was no logo: the name was set in plain type wherever a mark would go (design-system readme, MS-100 D15). That line is superseded. The tickets that put the brand into the product are listed at the end.

## The mark

A molar with a check cut out of the crown. The check is always a cut-out, never a stroke on top.

| | |
|---|---|
| Blue | `#1A63D6`, the design-system `primary` token (`Color.ms.primary`) and the app `AccentColor` |
| Cream | `#FFFEFB`, the `canvas` token |
| Ink | `#201515`, the `ink` token |

The three brand colours are already the three core design-system colours, so no token changes: the app, the landing page and the emails use the same values. The wordmark is Outfit Medium, outlined in the SVGs, so no font is needed to show it; the app already ships Outfit for its display type.

## Rules (from the designer)

- Clear space: half the tooth's height on every side.
- Minimum size: tooth 16 px, lockup 96 px wide.
- The check stays a cut-out. No outlines, effects or other colours. Never the blue tooth on blue.
- At 16 px the check is left out so the tooth stays clean (`web/favicon-16.png`, the 16 px slot of `favicon.ico`).
- At 40 pt and below in the iOS icon the tooth is larger and the check thicker (`ios/AppIcon-AllSizes.appiconset`).

## Inventory

### `logo/`: mark, wordmark and lockup

| File | What | Format |
|---|---|---|
| `dentory-mark.svg`, `dentory-mark.png` | Tooth only, blue, tight crop | SVG; PNG 902 × 1024 RGBA |
| `dentory-mark-ink.svg` | Tooth only, ink, for cream backgrounds in print | SVG |
| `dentory-mark-cream.svg` | Tooth only, cream, for blue or ink backgrounds | SVG |
| `dentory-lockup.svg`, `dentory-lockup.png` | Blue tooth + ink wordmark, for cream and white backgrounds | SVG 187.9 × 41.6 units; PNG 1600 × 354 RGBA |
| `dentory-lockup-reversed.svg`, `dentory-lockup-reversed.png` | Cream tooth + cream wordmark, for ink and blue backgrounds | SVG; PNG 1600 × 354 RGBA |
| `dentory-wordmark.svg` | Wordmark only, ink | SVG 140.1 × 36 units |
| `dentory-icon.svg` | App icon artwork, square: cream tooth on blue | SVG 1024 × 1024 |
| `dentory-icon-rounded.svg`, `dentory-icon-rounded.png` | The same artwork with iOS corners, for mock-ups and marketing (never for the asset catalog: Apple rounds the corners itself) | SVG; PNG 1024 × 1024 RGBA |

The SVGs carry C2PA content-credential metadata from the export (8 to 14 KB each). Harmless; strip it only if a file size ever matters.

### `ios/`: app icon

| File | What |
|---|---|
| `AppIcon.appiconset/` | The single-size set for Xcode 15+ and iOS 17+: `AppIcon-1024.png` (light, RGB, no alpha), `AppIcon-1024-dark.png` (blue tooth on transparent, the system adds the dark backing), `AppIcon-1024-tinted.png` (white tooth on transparent, greyscale, the system tints it), plus `Contents.json` with the `universal` / `ios` idiom and the `luminosity` appearances. This is what MS-158 copies into `Dentory/Resources/Assets.xcassets/AppIcon.appiconset`. |
| `AppIcon-AllSizes.appiconset/` | Every legacy size (20 pt to 83.5 pt at 1x, 2x, 3x, plus `ios-marketing` 1024) for an older Xcode or a non-iOS target. Not used by the app; kept for reference. |
| `dentory-app-store-1024.png` | For App Store Connect (MS-152): 1024 × 1024, RGB, no alpha, square corners. Pixel-identical to `AppIcon-1024.png`. |

All PNG icons are 1024 × 1024 and pass Apple's checks: the light icon has no alpha channel, the dark and tinted variants have transparency as the Human Interface Guidelines ask.

### `web/`: favicons and web app manifest

| File | What |
|---|---|
| `favicon.ico` | 16, 32 and 48 px (the 16 px slot has no check) |
| `favicon.svg` | Vector favicon, 64 × 64 viewBox, cream tooth on blue |
| `favicon-16.png`, `favicon-32.png` | PNG fallbacks |
| `apple-touch-icon.png` | 180 × 180, RGB |
| `icon-192.png`, `icon-512.png` | PWA icons, RGBA |
| `maskable-512.png` | PWA maskable icon, RGB, with safe-zone padding |
| `site.webmanifest` | Name, icons, `theme_color #1A63D6`, `background_color #FFFEFB` |

The `<head>` lines from the designer:

```html
<link rel="icon" href="/favicon.ico" sizes="any">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="manifest" href="/site.webmanifest">
```

### `android/`: adaptive icon

`res/` (vector foreground, blue background colour, monochrome layer for themed icons), `ic_launcher_foreground-432.png` and `play-store-512.png`. Dentory is iOS only (MS-100 D1); there is no Android app and no ticket. Kept for a future Android build.

## Not in the export

- No App Store screenshots, feature graphic or social-media images; MS-152 captures screenshots from the shipped build.
- No launch-screen artwork beyond the mark; MS-160 composes the launch screen from `logo/dentory-mark.svg` on cream.
- No brand typography files beyond the outlined wordmark; the app's Outfit and Inter fonts are in `Dentory/Resources/Fonts`.
- No colour variants beyond blue, cream and ink; the status colours stay the design system's.

## Tickets that use these files

| Ticket | Uses |
|---|---|
| MS-158 · App icon | `ios/AppIcon.appiconset` into the Xcode asset catalog; `ios/dentory-app-store-1024.png` for App Store Connect |
| MS-159 · Brand mark and wordmark in the app | `logo/dentory-mark.svg`, `logo/dentory-lockup.svg` as asset-catalog images and a design-system component |
| MS-160 · Launch screen | `logo/dentory-mark.svg` on a cream launch screen |
| MS-161 · Landing page dentory.ca | `logo/dentory-lockup.svg`, `logo/dentory-lockup-reversed.svg`, `web/` favicons and manifest, the brand colours in `site/` |
| MS-162 · Brand in emails and link pages | `logo/dentory-lockup.png`, `logo/dentory-lockup-reversed.png` in the transactional emails and the universal-link fallback page |
