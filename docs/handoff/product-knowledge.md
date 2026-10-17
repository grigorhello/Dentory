# Dentory product knowledge

Written for marketing, sales, support, pricing and pitch work. Every statement comes from PRD v1.1 (`design/PRD-v1.1.md`, dated 2026-10-14) or from the decisions in GitHub issue MS-100 (#71). When the product changes, this file changes with it. Status on 2026-10-16: the database and the stock engine are built; the app screens are being built; no clinic uses it yet.

## 1. One paragraph

Dentory is an iPhone and iPad app that tells a small dental clinic what it has, what is running low and what is expiring, without constant counting or scanning. Stock moves through five events only: a procedure takes supplies out, a delivery brings them in, a count or an adjustment corrects, a disposal removes, a cancelled procedure returns. Every event is recorded with who and when. The daily user is the dental assistant: pick a procedure, start it, done. The admin receives deliveries, maintains products and templates, and buys. Billing is per clinic, unlimited users: a 3-month free trial, then $99 per month.

## 2. The problem it solves

- Small clinics track supplies in heads, spreadsheets or not at all. They find out a cartridge box is empty when the patient is in the chair, and find expired lots in the drawer.
- Existing inventory tools are built for warehouses or large groups: barcodes, purchase orders, integrations, training. A two-chair practice does not have an inventory manager.
- The person who uses supplies (the assistant) is not the person who buys them (the owner or office manager). Nothing connects the two.

Dentory connects them with the least possible manual work: the procedure is the unit of consumption, the invoice is the unit of receiving, and counting is a correction, not a routine.

## 3. Who it is for

- **Clinic:** a small dental practice, one location, a handful of staff, ordering from a supplier by phone, email or web shop.
- **Admin:** the practice owner, the office manager or whoever owns inventory. Sets up the clinic, invites the team, receives deliveries, maintains products and procedure templates, marks items as ordered, handles settings and billing.
- **Staff:** dental assistants and hygienists. Start procedures, correct quantities, count stock, add items to the shopping list, open and finish bottles. Staff join by invitation only; there is no public staff sign-up.

A clinic always has at least one Admin. Role gating hides controls rather than greying them out, so the Staff screens are simpler, never locked.

## 4. What it does (features as a user sees them)

**Home: what needs me today.** Three attention tiles (To buy, Expiring soon, Missing expiry), a dark procedure card with Start a procedure and the latest procedure's Edit usage, two value tiles (Inventory value, At risk in 90 days), and, for Admins, the Receive delivery row. No feed, no charts.

**Procedures.** One row per template with a warning only when something is short. Adjust, then start: steppers per supply, add or remove items, a Take new button for bottles, syringes and kits that are opened fresh, then Start procedure · N items. Stock changes immediately; mistakes are fixed from history (Edit usage writes only the difference; Cancel procedure needs a note and returns everything). Starter quantities are templates, not clinical recommendations.

**Inventory.** Browse, search, filter (All, Low, Expiring, Missing expiry, Healthy). Count stock turns the same list into steppers, with a Review corrections step before Apply count. Product detail shows the quantity as a system estimate, minimum and target, usage in the last 30 days, the expiry card as the headline (batches soonest first, days left, lot as free text), bottles for multi-use products (unopened and open, who opened which), and history.

**Receive a delivery (Admin).** Take a photo or upload a PDF or image of the supplier invoice; the app reads it server side (usually under 20 seconds) and proposes one line per item as Matched, Possible match, New product or Needs review. The admin confirms every line; nothing touches inventory before Confirm & receive. Packs convert to counted units (5 boxes become 250 cartridges), unit cost is stored, batches are created with lot and expiry, matching To buy items become Received. Receive manually is always available.

**To buy.** A shopping list the clinic takes to its supplier, not an ordering system. Items are added automatically when a product goes Low or Out of stock (suggested quantity = target minus current), or by hand by anyone. Segments To buy, Ordered, Received. Admins select items and Mark N as ordered; receiving the invoice closes the loop.

**Expiring soon.** 30, 60 and 90-day windows, one card per batch with value at risk. Admins Mark disposed with the quantity, recorded as a Disposal.

**Activity.** The bell opens Alerts (out of stock, low, expiring, missing expiry, invoice ready to review; each deep-links to what resolves it and clears itself) and History (every stock event grouped by day with who, when, reason and delta).

**Team, settings, billing.** Invite by email with a role, resend or revoke, change roles. Clinic settings: logo, name, city, country, currency, time zone, expiry warning window (30/60/90, 60/90 or 90 only), weekly email digest. Billing: trial card, price, payment method on a secure Stripe page, invoices, billing emails. Export CSV of products, batches and transactions by email.

**Notifications.** In-app alerts are the source of truth; push (opt-in: out of stock, expiring within 30 days, invoice ready) and a Monday 7 am email digest mirror them. Invitation and password emails are always sent.

**iPad.** Same screens and tabs, content centred at a comfortable width, both orientations.

## 5. What makes it different (claims that are true)

1. **No scanning, no barcodes.** Consumption comes from the procedure, receiving from the invoice photo. Counting is a correction, done from the same list.
2. **AI reads the invoice, a person confirms every line.** Low-confidence lines are shown as Possible match or Needs review and are never applied on their own. Fees and surcharges never become stock.
3. **Built for two roles, not an org chart.** Admin and Staff. Staff see fewer buttons, never disabled ones.
4. **Expiry is the headline.** Every product page leads with its batches, soonest first; stock is used soonest-expiring first; value at risk is a number on Home.
5. **Multi-use products handled honestly.** Bottles, syringes and kits are tracked as unopened plus open items with who opened them and when. No percentage guesses.
6. **A shopping list, not a purchasing module.** To buy fills itself from minimums and targets; the clinic keeps ordering from the supplier it already has.
7. **Everything is auditable.** Every change carries user, time and reference; nothing is hard-deleted; products are archived; reversals are new records.
8. **Mistakes are fixed, never blocked.** Stock can go negative and shows as Out of stock; a procedure can be edited or cancelled from history with a note.
9. **Per-clinic pricing with unlimited users.** Adding the whole team costs nothing extra.

## 6. What it does not do (do not promise these)

Ordering through the app or supplier integrations, barcode scanning, patient or appointment data of any kind, multi-location clinics, practice-management integrations, Android, Google sign-in, in-app purchase, level estimates for open bottles, an onboarding checklist. V1.1 is English only.

## 7. Pricing and billing

- 3-month free trial from clinic creation; no card needed to start.
- $99 per clinic per month after the trial, unlimited users. Some clinics get a 50% lifetime promotion ($49.50), a flag set by Dentory, not in the app.
- Payment on a Stripe-hosted page opened from the app (Stripe Checkout, then the Customer Portal); invoices and billing emails in the app.
- When the trial ends without a payment method the app keeps reading access and blocks writes until one is added; the admin sees it on Home and Billing.

## 8. Privacy, security and reliability (for the trust questions)

- No patient or appointment fields exist anywhere in the product. Invoice images belong to the clinic and an admin can delete them.
- Data is isolated per clinic in the database (row-level security on every table), and Staff permissions are enforced by the database, not only by the app.
- All stock changes are server-side transactions in an append-only ledger; a retried request changes nothing twice; several users can act at once (two assistants each opening a bottle).
- Undo exists for single reversible actions (adjustment, invoice received, disposal, added to To buy) for a few seconds; there is no silent deletion.
- Hosting: Supabase (Postgres, Auth, Storage, Edge Functions) in the US east region for the pilot; Stripe for payments; Resend for email; Apple push. The invoice reading model runs server side; the clinic's invoice never leaves the server path.
- Performance targets: 500 products scroll smoothly; starting a procedure or applying a count under 1 second; invoice reading under 20 seconds with a progress state.

## 9. Vocabulary (use these words exactly)

To buy · Mark as ordered · Receive delivery · Confirm & receive · Receive manually · Count stock · Review corrections · Apply count · Adjust · Add to buy · Add expiry · Edit batch · Open a new bottle · Finished · Start procedure · Edit usage · Cancel procedure · Opened a new one? · Take new · Mark disposed · Expiring soon · Missing expiry · Alerts · History · Account · Team · Clinic settings · Billing.

Status words: Healthy, Low, Out of stock, Expiring, Missing expiry. Invoice line states: Matched, Possible match, New product, Needs review, Created, Skipped.

Copy style everywhere, including marketing that quotes the product: sentence case, numbers first, one idea per line, state the consequence ("Stock levels update immediately."), label estimates ("est. 54"), no exclamation marks, no emoji, no "please".

## 10. Look and feel

Cream page (#fffefb) with cream-soft cards (#f8f4f0), ink text, one blue primary action per screen, status as text plus a soft tint (never a large colour fill), Outfit for display titles, Lucide icons, bottom sheets for short forms, dark ink card for the one featured block per screen. The design system (tokens and components) is in the repo under `design/project/_ds/`; the 38 screens are in `design/frames/` and make good marketing material once the app matches them. The clickable prototype is `design/project/Dentory Mobile.dc.html`.

## 11. Roadmap and status

| Milestone | Content | Status 2026-10-16 |
|---|---|---|
| M0 Foundations | Decisions, iOS project, design system, Supabase local and CI, schema, permissions, stock engine, status rules, app core, app shell, error handling, demo seed | 7 of 12 tickets merged; MS-107 in progress |
| M1 Internal Alpha | Sign in and sign-up, invitations, Home, Inventory, product detail, create and edit products, adjust, expiry batches, bottles, count stock, procedures list and start, edit from history, password reset, templates | not started |
| M2 Clinic Pilot | Receive delivery (manual and AI invoice reading, review, confirm), To buy, Expiring soon, Activity alerts and history, pilot readiness pass, inventory value | not started |
| M3 Commercial Beta | Account, team management, Stripe billing, read-only mode after trial, clinic settings, push notifications, billing invoices and emails, CSV export, weekly digest, invoice file deletion, product analytics | not started |
| M4 V1 Launch | Security review, iPad pass, accessibility and Dynamic Type pass, performance and backups, TestFlight and App Store | not started |

58 tickets, 185 points in total. The pilot is one clinic on the hosted staging project; production is set up before TestFlight.

## 12. Pilot plan and metrics (from PRD v1.0, still the intent)

- Pilot with one small clinic: seed the catalog from the first deliveries, run procedures for two to four weeks, then review alerts and counts with the owner.
- Metrics that matter: procedures started per working day, deliveries received through the invoice reader versus manually, products with Missing expiry (should fall over time), low-stock surprises reported by staff (should fall to zero), time from invoice photo to confirmed receipt.
- Risks named in the PRD: invoice reading quality on real supplier formats; staff forgetting to start procedures; catalog naming drift (fixed by the Possible match flow); App Store acceptance of web billing for a B2B subscription (MS-100 D11, to confirm before submission).

## 13. Numbers and names to use consistently

- Product name: Dentory (called MediSave until 2026-10-17). Domain `dentory.ca`. Bundle id `ca.dentory.app` (confirmed 2026-10-17). Email links on `app.dentory.ca`, sending from `@dentory.ca` (D12); DNS and universal links land with MS-112 and MS-157.
- Platforms: iPhone and iPad, iOS 17 or later. Portrait on iPhone, both orientations on iPad.
- Roles: Admin, Staff (two words, capitalised).
- Trial: 3 months. Price: $99 per clinic per month. Promotion: 50% lifetime.
- Expiry windows: 30, 60, 90 days. Alert colours: danger at 30 days or less, warning at 31 to 90.
- Invoice reading target: under 20 seconds.
