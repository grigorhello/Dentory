# App Store Connect record for Dentory

Written 2026-10-19 while Grigor set up the app record. The goal is a complete record, ready for the first TestFlight build (MS-152), not a submission. Everything to type is in this file; the thread "App Store setup" in the project walks through it one screen at a time.

Facts: app name Dentory, bundle id `ca.dentory.app` (permanent at the first upload), SKU as Grigor entered it, iPhone and iPad, iOS 17 or later, version `1.1.0` (the project's `MARKETING_VERSION`), free on the App Store with no in-app purchase (decision D18 below).

## The path

| Step | Where | What it leaves behind |
|---|---|---|
| 0 | developer.apple.com, Membership details | Team ID (10 characters) for the hand-off in step 6 |
| 1 | Sidebar, General, App Information | Name, subtitle, categories, content rights, age rating 4+ |
| 2 | Sidebar, General, Pricing and Availability | Free, Canada only, no pre-order |
| 3 | Sidebar, General, App Privacy | Privacy policy URL and the published data label |
| 4 | Sidebar, iOS App, 1.0 Prepare for Submission | Version 1.1.0, text, URLs, copyright, App Review information, manual release |
| 5 | TestFlight tab | Test information and the internal group |
| 6 | Build thread on the Mac | Team ID in `applinks/`, signing team in Xcode, encryption key in Info.plist |

The sidebar labels are Apple's as of October 2026. If a screen looks different, say what it shows and the thread adapts.

## Step 0. Agreements and Team ID

1. If App Store Connect shows a yellow banner about an updated Apple Developer Program License Agreement, accept it (the Account Holder does this at developer.apple.com, Agreements). Builds cannot be uploaded while it waits.
2. Team ID: developer.apple.com, Account, Membership details, "Team ID". It is public (it goes into a file every browser can read), not a secret.
3. Nothing in Business, Agreements, Tax and Banking is needed: the app is free and sells nothing through Apple, so the Paid Apps agreement stays unsigned.

## Step 1. App Information

Sidebar, General, App Information. Save at the top right when done.

| Field | Value |
|---|---|
| Name | Dentory |
| Subtitle | Dental stock, without counting |
| Primary language | Whatever was chosen when the app was created; English (U.S.) and English (Canada) both work |
| Bundle ID, SKU, Apple ID | Already set; the Apple ID is Apple's number for the app |
| Primary category | Business |
| Secondary category | Medical |
| Content rights | "No, it does not contain, show, or access third-party content" |
| License agreement | Apple's standard EULA (leave as is) |
| Age rating | "Set Up Age Ratings" or "Edit"; answers below |

Age rating questionnaire (Apple's 2025 version; the result is 4+):

- In-app controls (parental controls, age assurance): none ticked.
- Capabilities: unrestricted web access No, user-generated content No, messaging or chat No, advertising No, social media No.
- Every content description (violence, sexual content, profanity, horror, mature themes, medical or treatment information, health and wellness, alcohol, tobacco and drugs): None. Dentory lists supplies; it gives no medical or treatment information.
- Chance-based: simulated gambling None, contests None, gambling No, loot boxes No.
- Age categories and override: Not Applicable. Age suitability URL: empty.

## Step 2. Pricing and Availability

Sidebar, General, Pricing and Availability.

| Section | Value |
|---|---|
| Price schedule | Add pricing, base country Canada, price CAD 0 (Free), start now |
| App availability | Set up availability, Canada only (decision D18; expand in one click when a clinic outside Canada signs up) |
| Pre-orders | Leave off |
| App distribution methods | Public |
| Tax category | Not shown for a free app |

Why free with no in-app purchase: the subscription is sold directly to clinics, which Apple's App Review Guideline 3.1.3(c) (enterprise services) allows outside in-app purchase. Outside the United States storefront an app may not carry a button, link or call to action to an outside purchase, so the app shows billing status only and the payment page travels by email. Details under D18.

## Step 3. App Privacy

Sidebar, General, App Privacy.

1. Privacy Policy URL: `https://dentory.ca/privacy`. The page is `site/privacy.html` in the repository and goes live with GitHub Pages and the domain (MS-161 and Grigor's DNS); Apple reads it at review time, not now. Its placeholders DATE and EMAIL are Grigor's to fill.
2. Get Started, then "Yes, we collect data from this app".
3. Tick these data types and nothing else:

| Category | Data type | Linked to the user | Tracking | Purpose |
|---|---|---|---|---|
| Contact Info | Name | Yes | No | App Functionality |
| Contact Info | Email Address | Yes | No | App Functionality |
| User Content | Photos or Videos (invoice photos) | Yes | No | App Functionality |
| User Content | Other User Content (products, batches, stock events) | Yes | No | App Functionality |
| Identifiers | User ID | Yes | No | App Functionality, Analytics |
| Diagnostics | Crash Data | No | No | App Functionality |
| Diagnostics | Performance Data | No | No | App Functionality |
| Diagnostics | Other Diagnostic Data | No | No | App Functionality |
| Usage Data | Product Interaction | Yes | No | Analytics |

Not collected, so not ticked: Health and Fitness (no patient data), Location (PostHog's location from the IP address is turned off), Financial Info (card numbers go to Stripe's hosted page, never through the app or Dentory's servers), Purchases, Phone Number, Device ID. The diagnostics rows come from Sentry Cocoa, which runs only when `SENTRY_DSN` is set and sends no names, emails or screenshots (`SentryErrorReporter`). Usage Data, Product Interaction comes from PostHog (MS-147), which runs only when `POSTHOG_PROJECT_TOKEN` is set: events named by the Appendix B ids with counts and closed words, linked to the user id and the clinic id, never names, emails or typed text (`docs/handoff/analytics.md`); tick it before the first build with a token goes to TestFlight testers outside the team or to the App Store. Later tickets add rows: MS-141 (billing invoices in the app) adds Purchases, Purchase History; MS-144 (push) stays as is unless a device token is stored with the user.

4. Publish. The label can be edited and republished at any time.

## Step 4. The version page

Sidebar, iOS App, "1.0 Prepare for Submission". Save at the top right; do not click "Add for Review".

| Field | Value |
|---|---|
| Version | 1.1.0 (replace 1.0; it must match the build's `MARKETING_VERSION`) |
| Screenshots | Leave empty until MS-152. Apple then needs one set per display: iPhone 6.9-inch at 1320 × 2868 px and iPad 13-inch at 2064 × 2752 px, 1 to 10 each, PNG or JPG without transparency; Apple scales them for smaller devices. Capture from the shipped build; Apple rejects screenshots that do not match the app. Order and captions in `/mnt/project-files/marketing/app-store-listing.md`. |
| App previews | None |
| Promotional text | 3 months free for clinics. Know what is running low and what is expiring. The assistant starts a procedure, you photograph the invoice, and stock takes care of itself. |
| Description | The "Description" block of `app-store-listing.md`, pasted as is |
| Keywords | dental,inventory,clinic,supplies,expiry,stock,dentist,hygienist,assistant,practice,lot |
| Support URL | https://dentory.ca/support |
| Marketing URL | https://dentory.ca |
| Copyright | 2026 followed by the owner of the app: Grigor's full name for an individual Apple Developer account, the company name for an organization account. No © sign; Apple adds it. |
| Routing app coverage file | None |
| Build | Comes with MS-152 |
| App icon | Comes from the build's asset catalog (`AppIcon.appiconset`, MS-158); nothing to upload here |
| Game Center, App Clip | Off |
| Version release | "Manually release this version" |

App Review Information (Apple reads it, customers never do):

- Sign-in required: on. Username and password: the demo clinic's Admin account on the production Supabase project; it does not exist yet, so leave both empty until MS-152 and add the Staff account in the notes then.
- Contact information: Grigor's first name, last name, phone in international form (+1 and the number, no spaces needed) and email.
- Notes, pasted:

> Dentory is an inventory app for dental clinics, sold directly to clinics as a per-clinic subscription (App Review Guideline 3.1.3(c), enterprise services). There is no in-app purchase, and the app has no purchase button or link: it shows the clinic's trial or subscription status. Dentory sets each clinic up in person and sends the payment page by email. Sign-in is by email and password; staff join through an emailed invitation. The app holds no patient or appointment data. Demo clinic: Admin [email, password]; Staff [email, password]. Home shows what needs attention, Inventory lists the products, Procedures deducts stock, Receive delivery reads a supplier invoice from a photo.

## Step 5. TestFlight

TestFlight tab, then "Test Information" in the sidebar.

| Field | Value |
|---|---|
| Beta app description | Dentory tells a small dental clinic what it has, what is running low and what is expiring. Try the demo clinic or create your own: start a procedure, receive a delivery from an invoice photo, check Expiring soon and To buy. |
| Feedback email | Grigor's email |
| Marketing URL | https://dentory.ca |
| Privacy policy URL | https://dentory.ca/privacy |
| Beta App Review information | Same contact, sign-in and notes as step 4 (needed only for external testers) |
| License agreement | Apple's default |

Internal Testing in the sidebar: "+" next to Internal Testing, group name "Dentory team", "Enable automatic distribution" on, add Grigor (every App Store Connect user with the app can be an internal tester, up to 100). An external group "Pilot clinics" comes with MS-152; it needs Beta App Review and the demo account.

Users and Access needs nothing now. To let someone else see TestFlight builds or reply to reviews later, add them there with the Customer Support or Marketing role.

## Step 6. Hand-off to the build thread

These change the iOS project and are the build thread's ("Implementing the tickets", on the Mac), one small PR:

1. `applinks/.well-known/apple-app-site-association`: replace `TEAMID` with the Team ID. Universal links start working once `app.dentory.ca` serves the file.
2. `project.yml`, under `settings.base`: `DEVELOPMENT_TEAM` set to the Team ID and `CODE_SIGN_STYLE: Automatic`, then `make project`. In Xcode, Signing and Capabilities shows the team and registers the App ID with the Associated Domains capability. The Push Notifications capability and an APNs key (developer.apple.com, Keys) come with MS-144.
3. `Dentory/Resources/Info.plist`: `ITSAppUsesNonExemptEncryption` set to `false`. The app uses only HTTPS, which is exempt, and the key answers the export compliance question for every build instead of a prompt on each upload.
4. First archive and upload: Xcode, Product, Archive, Distribute App, App Store Connect (MS-152). The build then appears under TestFlight and on the version page.

## D18, recorded in MS-100 and `decisions-log.md`

Billing stays outside Apple, as D11 chose, and now checked against the guideline: the app is free on the App Store with no in-app purchase, and the clinic subscription is sold directly to clinics through Stripe (3.1.3(c), enterprise services; consumer or single-user sales would need in-app purchase, and Dentory has none). What changes from D11: the app never opens the Stripe page. Account, Billing shows the trial or subscription state, the price line and the payment-method status (not set, or the card's last digits); the Stripe Checkout link for the payment method and the Customer Portal link for changes reach the clinic by email (the welcome email, the trial reminders, Stripe's receipts) and from Grigor at onboarding. The read-only sheet after an ended trial points to the billing email, not to a web page. Invoices in the app (MS-141) list amount, date and status without links. MS-140, MS-141 and MS-142 follow this. The App Store record also fixes: Canada only until the pilot ends, age rating 4+, manual release, version 1.1.0, screenshots only from the shipped build.
