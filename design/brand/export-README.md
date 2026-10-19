# Dentory icons

Mark: molar with a check cut out of the crown.
Colors: Blue #1A63D6 · Cream #FFFEFB · Ink #201515

## iOS (iPhone and iPad)
- ios/AppIcon.appiconset: Xcode 15+ single-size set with light, dark and tinted (1024 px). Replace AppIcon in Assets.xcassets with it.
- ios/AppIcon-AllSizes.appiconset: every size, for older Xcode or targets. At 40 pt and below the tooth is larger and the check thicker.
- app-store/dentory-app-store-1024.png: for App Store Connect. RGB, no alpha, square corners (Apple rounds them).

## Android
- android/res: adaptive icon (vector foreground, blue background, monochrome for themed icons). Copy into app/src/main/res.
- android/play-store-512.png: Google Play listing.

## Web
- web/: favicon.ico (16, 32, 48), favicon.svg, apple-touch-icon.png, icon-192.png, icon-512.png, maskable-512.png, site.webmanifest.

    <link rel="icon" href="/favicon.ico" sizes="any">
    <link rel="icon" href="/favicon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/apple-touch-icon.png">
    <link rel="manifest" href="/site.webmanifest">

At 16 px the check is left out so the tooth stays clean.

## Brand
- brand/dentory-mark.svg, -ink.svg, -cream.svg: tooth only, tight crop.
- brand/dentory-lockup.svg, -reversed.svg (+ PNG): tooth and wordmark. Wordmark is Outfit Medium, outlined.
- brand/dentory-wordmark.svg: wordmark only.
- brand/dentory-icon.svg, -rounded.svg (+ PNG): app icon artwork.

## Rules
- Clear space: half the tooth's height on every side.
- Minimum size: tooth 16 px, lockup 96 px wide.
- The check stays a cut-out. No outlines, effects or other colors. Never the blue tooth on blue.
