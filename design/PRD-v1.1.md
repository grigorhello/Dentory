# Dentory PRD v1.1 (text export)

Exported from the Claude Design project file `project/Dentory PRD v1.1.dc.html` so it can be read without a browser. Frame images are in `frames/`. Where the PRD said "live preview", see the matching frame image.

Dentory · Product requirements

Dental inventory app, V1.1 (iPhone and iPad)

Version 1.1 · October 14, 2026 · Status: ready for development. Supersedes PRD v1.0 (October 1, 2026) wherever the two differ. Written from the approved design; every rule below is visible in a screen.

Design boardDentory Board · every screen, Admin and Staff versions, grouped by flow

Clickable demoDentory Mobile · tap through all flows; Tweaks switch role, device and start screen

Design systemDentory Design System (tokens, Button, Badge, Input, Select, Switch, Card, Icon, Dialog, Toast)

Source PRDuploads/dental_inventory_saas_sellable_mvp_prd.pdf

The screens embedded in this document are live previews of the demo. Frame numbers (f1…f38) match the board.


## 1. Summary

Dentory tells a small dental clinic what it has, what is running low and what is expiring, without constant counting or scanning. Stock moves through five events only: a procedure takes supplies out, a delivery brings them in, a count or an adjustment corrects, a disposal removes, a cancelled procedure returns. Every event is recorded with who and when.

V1.1 is a native-feeling mobile app for iPhone and iPad with two roles. The daily user is the dental assistant: pick a procedure, start it, done. The admin receives deliveries, maintains products and templates, and buys.

What changed since v1.0

Two roles: Admin and Staff. Inventory Manager is merged into Admin.

No Prepared state. Starting a procedure deducts immediately; past procedures are edited or cancelled from history.

Multi-use products (bottles, syringes, kits) are tracked as unopened count + open items (who, when). No percentage estimates.

No Quick count feature. Counting lives inside Inventory as Count stock.

To buy is a shopping list, not ordering. The clinic orders from its supplier outside the app.

Accounts are created by the clinic admin; staff join by invitation only.

Billing: 3-month free trial, then $99 per clinic per month; some clinics get a 50% lifetime promotion.

Out of scope for V1.1

Ordering through the app or supplier integrations, barcode scanning, patient or appointment data, multi-location clinics, practice-management integrations, Android.


## 2. Users and roles

Admin: practice owner, office manager or the person who owns inventory. Staff: dental assistants and hygienists. A clinic has at least one Admin. Where a screen differs by role, the board shows the Staff version directly below the Admin one; identical screens are tagged Admin/Staff.

| Capability | Admin | Staff |
|---|---|---|
| Sign up, create the clinic, invite teammates, set roles | Yes | No |
| Start a procedure, edit its usage later, cancel it with a note | Yes | Yes |
| Create and edit procedure templates (default supplies) | Yes | No |
| Browse, search and filter inventory; open product detail | Yes | Yes |
| Count stock and apply corrections | Yes | Yes |
| Adjust a quantity with a reason | Yes | Yes |
| Add expiry; edit a batch (date, lot, quantity) | Yes | Yes |
| Open a new bottle, mark a bottle finished | Yes | Yes |
| Add to To buy, change suggested quantities | Yes | Yes |
| Select items and mark them as ordered | Yes | No |
| Receive a delivery (invoice or manual) | Yes | No |
| Create, edit, delete products | Yes | No |
| Mark expiring stock disposed | Yes | No |
| Clinic settings, billing, CSV export | Yes | No |
| View the team list | Yes | Read-only |
Role gating hides controls; it never shows a disabled control. Staff screens therefore have fewer buttons, never greyed ones.


## 3. Navigation

Four tabs: Home · Inventory · Procedures · To buy. The To buy tab carries a red count badge equal to the number of items in the To buy list.

Home header: date eyebrow, clinic name, bell (opens Activity; red dot when there are unread alerts) and a generic profile icon (opens Account).

Root screens show a 32px display title and the tab bar. Pushed screens show a 44px back chevron, a 24px title, no tab bar, and pin their primary action to the bottom.

Sheets (bottom, grab handle, dim scrim) hold short forms, pickers and confirmations. Toasts confirm completed actions. No full-screen dialogs.

Receive delivery, Expiring soon, Activity and Account are one tap from Home, not tabs.


## 4. Data model

| Entity | Fields and rules |
|---|---|
| Clinic | Name, logo (optional), city, country, expiry warning window (30/60/90 options), weekly email digest on/off, billing plan, billing emails (one or more; the admin's is first and cannot be removed). |
| User | Name, email (unique per clinic), role Admin or Staff, status Active or Invited (with invite date). |
| Product | Name (as written on the box), category, counted-in unit (e.g. cartridges), optional received-as pack (e.g. box) with pack size (1 box = 50 cartridges), minimum, target, supplier (optional, set from the first invoice), location (optional, free text), tracking mode: countable or multi-use. Quantity is the sum of its batches. Last unit cost from receiving. Deleting archives: the product leaves Inventory, To buy and templates; its history stays. |
| Batch | Expiry date (month precision), quantity, lot (optional, free text; the clinic decides what it writes there). Quantity without an expiry date is flagged Missing expiry. |
| Open item (multi-use only) | One record per open bottle, syringe or kit: opened by, opened on. Quantity shown = unopened + open. Finished removes the record. |
| Procedure template | Name, list of products with default quantity. Multi-use products in a template default to 0 (use the open one). Admin-only. |
| Procedure (event) | Template, started by, started at, supplies used [product, quantity], items opened [product]. Editable at any time; editing writes the difference as a transaction. Cancelling requires a note and returns everything. |
| To buy item | Product, quantity to buy (default target − current, editable), status To buy → Ordered (date) → Received (date). Added automatically when quantity ≤ minimum, or by anyone by hand. |
| Transaction | Append-only. Type Receiving, Procedure, Count, Adjustment, Disposal or Cancellation; product; delta; by; at; reference (invoice no., procedure); reason or note. Nothing is ever deleted; reversals are new transactions. |

## 5. Status and alert rules

| Status | Rule | Color |
|---|---|---|
| Out of stock | Quantity is 0 (multi-use: no unopened and no open). | Danger |
| Low | Quantity ≤ minimum (multi-use: unopened ≤ minimum). | Warning |
| Expiring | Any batch expires within the clinic's warning window. ≤ 30 days renders in danger text, 31–90 in warning. | Warning |
| Missing expiry | Some quantity has no expiry date. | Info |
| Healthy | None of the above. | Success |
One badge per product. Priority: Out of stock › Low › Expiring › Missing expiry › Healthy.

To buy auto-add fires when a product becomes Low or Out of stock; suggested quantity = target − current, recalculated until the item is marked Ordered. Receiving the product marks the item Received.

Inventory value = Σ quantity × last unit cost. Value at risk = Σ expiring batch quantity × last unit cost, for the selected window.

Alerts (bell): Out of stock, Low, Expiring within the window, Missing expiry, Delivery read and waiting for review. Each alert deep-links to the product or list that resolves it and clears when the condition clears.


## 6. Flows


### 6.1 Sign in, sign up and clinic setup f1–f5

The admin creates the account and the clinic; staff only ever accept an invitation.

Sign in: email, password, Forgot password. Footer: "Setting up a new clinic? Sign up as admin" starts admin sign-up; "Staff join through the invitation email." No public self-service for staff.

Step 1 · Account: name, email, password. Step 2 · Clinic: logo (tap the placeholder to upload; optional), clinic name, city, country. No currency or time zone questions; they derive from the device and country. Step 3 · Invite team: rows of name, email, role (Staff or Admin); Skip for now is allowed. Continue lands on Home.

Accept invitation (Staff): the email link opens the app on a screen showing the clinic name and who invited; the user sets a password and lands on Home. Links expire after 7 days; an admin can resend from Team.

Sessions persist on the device. Sign out lives in Account.


### 6.2 Home f6–f10

Home answers "what needs me today" and makes starting a procedure one tap.

Attention tiles (three, equal width): To buy, Expiring soon, Missing expiry. Big number in the status color (ink when 0), short label. Tap opens the matching list.

Procedure card (dark ink): primary button Start a procedure opens the Procedures list. Below a divider, Latest procedure: name, when, "N supplies · by", and Edit usage, which opens that procedure in editing mode. The latest procedure is always visible so quantities can be corrected during or right after treatment.

Value tiles: Inventory value (tap → breakdown by category) and At risk, 90 days (tap → Expiring soon).

Receive delivery row (Admin only): one tappable card "Receive delivery · Photo, PDF or manual. You confirm every line." with a chevron → Receive delivery (6.5), where the three options live. Hidden for Staff.

Order on screen: tiles, procedure card, value tiles, receive row. Nothing else; no feed, no charts.


### 6.3 Procedures f11–f15

The core daily flow. The assistant picks a procedure, corrects the list, starts. Stock changes immediately; mistakes are fixed from history, never blocked up front.

Procedures list

One row per template: name, item count, and a warning line only when something is short ("1 not available" in danger, "2 will run out" in warning). Nothing is shown when all is fine.

Admin: + Template in the header and a pencil per row open Edit defaults (name, items with steppers, + add item, Save). Staff see neither.

Note under the list: "Starting a procedure deducts its supplies right away. Starter quantities are templates, not clinical recommendations."

History · tap to edit usage: every past procedure, newest first; name, "date · N items · by".

Adjust, then start

Header: template name. Summary line "N supplies" plus a shortage count when relevant.

Supplies for this procedure: each row has −/+ steppers (40px), the quantity in blue when it differs from the default, and a remove X. A sub-line appears only when the item would run out ("0 will remain", warning) or is not available ("Not available · 2 in stock", danger). A round + button at the bottom right of the list opens Add item: a searchable, scrollable list of all products.

Opened a new one? section with an (i) icon (tap → toast: "Tap Take new when you open a fresh bottle, syringe or kit from stock. Using an already open one changes nothing."). It lists the template's multi-use products with "N open · N unopened". Take new is an outlined button; tapping it fills it blue, adds the product to the supplies list above with quantity 1, and the sub-line becomes "Will take 1 from stock · N unopened left". Tapping again removes it. If nothing is unopened, a toast says "Out of stock" and nothing changes. Which products appear here is defined by the admin in the template; there is no remove X.

Primary button pinned at the bottom: Start procedure · N items (count only, no breakdown). Start deducts every countable row, moves each Take-new product from unopened to open tagged with the user and today, records the procedure, returns to Procedures and shows a toast. Stock may go negative; it is shown as Out of stock, never blocked.

Cancel procedure (text button) before starting simply goes back; nothing was changed.

From history

Read-only view: banner "N items deducted · date · by"; list titled Supplies used with a Used column; multi-use rows read "Opened a new bottle" or "Used from open bottle".

Edit usage (tertiary, pencil) switches to editing: steppers, remove, + add item. Save changes writes only the difference to stock and to Activity ("Edited usage · name"). Discard leaves everything as recorded.

Cancel procedure (danger text) opens a sheet: title "Cancel {name}?", warning box "N items will be returned to inventory. Stock levels update immediately.", a required note "Why is it cancelled?" (placeholder "e.g. Logged by mistake, patient cancelled"), micro "Recorded in Activity with your name." The red button stays disabled until the note has text. Keep closes the sheet. Cancelling returns countables and reverses any bottle opened by this procedure.

Both roles see the same detail screens. Staff differ only in the list (no + Template, no pencil).


### 6.4 Inventory, counting and product detail f16–f21

One list serves browsing and counting. Expiry is the headline of every product page; lot is free text the clinic owns.

Inventory list

Header: title, Count stock button (clipboard-list icon). Search field. Filter chips: All, Low, Expiring, Missing expiry, Healthy (Low includes Out of stock).

Rows: name, "54 cartridges · Anesthetic" (multi-use: "1 unopened · 2 open · Sterilization"), status badge. Tap opens Product detail.

Admin: a round + button bottom right opens New product. Staff: no + button.

Empty search: "No products match."

Count stock

Same list, title becomes Count, header shows an X to cancel. Every row turns into −/+ steppers around the current quantity; sub-line "est. 54 cartridges · location". Changed values turn blue. Multi-use rows count unopened only ("Count unopened only").

Search and filters stay available, so a drawer or a category can be counted alone.

Bottom button Review · N corrections is disabled until at least one quantity changed. It opens Review corrections: each change as "43 → 41" with Undo, then Apply count · N corrections and Back to counting. Applying writes one Count transaction per changed product ("Physical count · by") and shows a toast without Undo.

Cancel with unsaved changes asks "Discard this count?" (N changes · "Inventory stays as it is.") with Discard count / Keep counting. Without changes it exits silently.

Product detail

Header: back, "Category · unit tracked", Edit (Admin). Title row: name and status badge.

Quantity card: large number with unit labelled "System estimate", Minimum, Target, then one line "N units used in 30 days · Counted {date}". When Low: "Recommended: add N units".

Actions: Adjust and Add to buy (Staff label: Report low stock; same effect). Add to buy puts the product on the list with the suggested quantity and shows a toast with Undo.

Expiry card (the headline): rows sorted soonest first, each with the date in bold and "in N days" (danger ≤ 30, warning ≤ 90, "Expired" when past), quantity, lot in monospace. Total line underneath. Tapping a row opens Edit batch (Expires month picker, How many, Lot optional free text, Save). Add expiry is always available under the card and adds a new batch; the total line reads "N of M tracked" so undated quantity is visible. Both roles.

Bottles card (multi-use only): "N unopened · N open"; one row per open item: "Open · {who}" / "opened N days ago" with Finished. Open a new bottle (disabled when none unopened) moves one from unopened to open under the current user. Several people can each have one open.

History: last transactions as delta, reason, when.

Admin only: Delete product (danger text at the bottom) → sheet "Delete {name}?" explaining stock still held and that the product is archived, not erased.

Sheets on this flow

Adjust inventory: "System estimate N unit. A reason is recorded in history." Actual quantity, Reason (Physical count, Expired, Damaged, Waste, Missing, Returned, Data correction, Other), Save adjustment. Toast with Undo.

New / Edit product: Name ("As written on the box"), Category. Units: Counted in (e.g. cartridges) and Received as (e.g. box); when a pack is given, "How many cartridges in 1 box?" and a plain sentence confirming the conversion ("Receive in boxes, count and use in cartridges. 1 box adds 50 cartridges."). A Multi-use switch marks bottles, syringes and kits (see gap G1). Stock levels: Minimum ("Alert below"), Target ("Reorder up to"). Micro: "Quantity, expiry and lot are entered on the receiving form." Button reads Create product, Save changes, or Create and use for this line (from an invoice). Disabled until a name is entered.


### 6.5 Receive a delivery f22–f24 · Admin

The invoice is the input; the admin confirms every line. Nothing touches inventory before Confirm.

Receive delivery: three options as cards: Take a photo (dark), Upload PDF or image, Receive manually. Micro: "Nothing affects inventory until you confirm." Below, Waiting for delivery lists items marked Ordered with supplier and date, for reference only.

Reading state: document placeholder, "Reading invoice", "Usually under 20 seconds", link Receive manually instead. Extraction runs server-side; the user may leave and gets an alert when it is ready.

Review invoice: header "Supplier · invoice no. · total". Banner: "AI read N lines. Check each one, then confirm." One card per line: the raw description in monospace, a state badge, and a one-line question. States and actions:

Matched: product name, "5 boxes · $49.80", Lot and Expiry inputs (month). Micro: "Skip now → listed under Missing expiry."

Possible match (hairline border): "Name differs slightly from your product." Buttons Yes, match / No, create new.

New product (hairline border): "No product with this name exists yet." Add new opens New product prefilled (banner "From invoice: {raw line}. Name and unit are suggested. Check them and add the rest."); Pick existing opens Which product is this?, a searchable list.

Needs review (hairline border; fees, surcharges): "Fees and surcharges should not become stock." Ignore / Pick product.

Resolved lines become Matched, Created or Skipped, lose the border, and show Lot and Expiry.

Footer: "N of M lines will increase inventory." or "Resolve every line to continue." Confirm & receive is disabled until every line is resolved. Confirm converts packs to counted units (5 boxes → 250 cartridges), stores unit cost, creates batches, marks matching To buy items Received, opens Inventory and shows "Delivery received · Inventory increased for N products." with Undo.

Receive manually: Choose product (searchable sheet with New), Quantity in the received unit with the conversion shown ("Current 1 → after 5 kits"), Cost per unit, Lot (optional), Expiry (month). Receive shows a toast without Undo.


### 6.6 To buy f25–f26

A shopping list the clinic takes to its supplier. The app never places orders; the wording avoids implying it does.

Segments with counts: To buy · N, Ordered · N, Received · N.

To buy rows: name, "Current 1 · target 5 · Patterson" (supplier only when known), quantity stepper. Admin rows have a checkbox. All items start selected; a bar reads "N of M selected · Clear" so the admin can untick what is not being ordered this time. The pinned button reads Mark N as ordered, N following the selection, and is disabled only when nothing is selected. A text Add item opens a searchable sheet of products not yet on the list.

Ordered rows: "N ordered Oct 1 · Patterson". No per-row receive: deliveries are received from the invoice (6.5), which moves items to Received automatically.

Received: history with date and supplier.

Staff: same screen without checkboxes and without Mark as ordered; they can add items and change quantities.

Empty segment: "Nothing here yet."


### 6.7 Expiring soon f27–f28

Segments 30 / 60 / 90 days. Summary: "N products · $X at risk within 90 days."

One card per batch: name, "quantity · lot · date", days left in danger (≤ 30) or warning, value. Buttons: View product; Admin also Mark disposed.

Mark disposed sheet: "{name} · lot X. Removed with reason Expired." Quantity disposed (default: the batch), red Mark disposed, Keep. Writes a Disposal transaction; toast with Undo.

Empty: "Nothing expires in this window."


### 6.8 Activity: alerts and history f8–f9

Opened from the bell. Two segments: Alerts and History.

Alerts: colored dot, one sentence ("Rubber dam latex-free is out of stock."), when. Tap deep-links to the product or list. Alerts clear themselves when the condition is gone.

History: filter chips All, Receiving, Procedures, Counts, Adjustments; grouped by day. Each row: product or procedure, reason line ("Invoice INV-10092", "Physical count", "Damaged"), then "Name · time" on its own line, and the delta on the right (+ in success, − in danger, "43 → 41" in ink). No undo from history; reversals are done by editing the procedure, adjusting, or receiving again.


### 6.9 Account, team, settings and billing f29–f35

Account: user card (generic profile icon, name, "Role · Clinic"). Admin groups: Team, Clinic settings, Billing, Export CSV; Help; Sign out (red). Staff: Team, Help, Sign out.

Team: rows with initials, name, email, role; pending rows read "Invited · date". Admin: Invite opens a sheet (Name, Email, Role Staff/Admin, Send invitation; toast "Invitation sent · They get a link by email."). Admin can resend or revoke an invitation and change a role from the row.

Clinic settings (Admin): logo (tap to replace), clinic name, city, country. Alerts: Expiry warning (30, 60 and 90 days · 60 and 90 · 90 only), Email digest switch (weekly, Monday 7 am). Save in the header; toast "Settings saved".

Billing (Admin): dark card "Free trial · N days left · Ends {date}". Price line "$99 per clinic / month after the trial", or "$49.50 · 50% lifetime promotion" when granted (flag set by Dentory, not editable in the app). Rows: Payment method (opens the secure card form), Invoices (→ Invoices screen; empty state "No invoices yet"), Billing emails (count; sheet to add or remove addresses; the admin's is first and not removable). Billing is per clinic, unlimited users.

Export CSV: products, batches and transactions, sent to the admin's email. Toast "Export started".


### 6.10 iPad f36–f38

Same screens and the same bottom tabs. Content is capped at 720px and centred; sheets are centred at the same width. Both orientations are supported; nothing becomes a sidebar or a two-pane layout in V1.1.


## 7. UX and UI standards

These rules keep every screen consistent and are the acceptance criteria for new screens. Tokens and components come from the Dentory Design System; do not introduce new colors, radii or type sizes.

| Area | Rule |
|---|---|
| Page | Cream page (#fffefb), 20px side padding, content max 720px. Root title Outfit 500 32px with a date or context eyebrow above; pushed title 24px with a 44px back chevron. Status bar area 54px. |
| Lists | Cream-soft card (#f8f4f0), 12px radius, 16px side padding, rows 12–14px tall padding, 1px line dividers (#e6e1d6). Row = title (14px ink), one caption line (12px secondary), right-side value or badge. Chevrons only on rows that navigate. |
| Primary action | One blue primary per screen, 48px, full width, pinned to the bottom in a bar with a hairline top. Label is a verb plus the count when it changes stock: "Start procedure · 6 items", "Apply count · 2 corrections", "Confirm & receive". Disabled until the action is valid; never hidden. |
| Secondary actions | Tertiary (hairline) buttons for Adjust, Count stock, View product; text buttons for Edit, Cancel, Undo. Icon + label at 20px Lucide, 1.75 stroke. Round 56px + button bottom right for "add" on lists. |
| Destructive | Red danger button only inside a confirmation sheet, always paired with a Keep text button, always preceded by one sentence stating the inventory effect. Actions that change stock backwards (cancel procedure) require a note. |
| Sheets | Bottom sheet, 20px top radius, 36×4 grab handle, scrim rgba(32,21,21,.4), 180ms fade, tap scrim to close. Title 24px, one caption line, fields, primary button last (full width). Lists inside sheets are 360px tall, scroll, and have a search field on top. |
| Toasts | Dark ink card above the tab bar, title + one detail line, 3.2 seconds. Undo only for single reversible actions: adjustment, invoice received, disposed, added to To buy. No Undo for counts, manual receive, start procedure. |
| Steppers | 40×40 −/+ with hairline, 6px radius, value 36–44px wide centred. A value that differs from default or estimate is primary blue. Minimum 0. |
| Segments and chips | Segmented control in a cream-soft track for 2–3 views (To buy · Ordered · Received, 30 / 60 / 90). Chips for filters: ink fill when active, cream-soft otherwise, horizontal scroll. |
| Status | Badge pill, text + soft tint, never a large fill. Status words: Healthy, Low, Out of stock, Expiring, Missing expiry; invoice lines: Matched, Possible match, New product, Needs review, Created, Skipped. |
| Emphasis | Ink hairline border on items that need a decision (invoice lines, soonest batch). Dark ink card for the one featured block per screen (procedure card, trial card). Soft tinted boxes for one-line notices (info, warning, success). |
| Copy | Sentence case. Numbers first. One line per idea; captions ≤ 60 characters. State the consequence ("Stock levels update immediately."). Label estimates ("est. 54"). No exclamation marks, no emoji, no "please". UPPERCASE only for eyebrows. |
| Empty and loading | Empty: hairline frame with one caption ("Nothing expires in this window."). Loading: cream placeholder rows; long tasks name themselves ("Reading invoice · Usually under 20 seconds"). |
| Errors | Field errors inline under the field in danger text. Save failures as a toast "Couldn't save. Try again." keeping the user's input. Offline: a one-line banner under the header; reading is allowed, writes are queued and retried. |
| Motion | 120–180ms, cubic-bezier(.2,0,0,1), fades and color only; sheets slide ≤ 8px with the fade. No bounces. |
| Accessibility | Hit targets ≥ 44px. Text ≥ 12px; body 14px. Contrast ≥ 4.5:1. Status always text + color. Supports iOS Dynamic Type up to the Large step without truncation. |
Vocabulary (use exactly these)

To buy · Mark as ordered · Receive delivery · Confirm & receive · Receive manually · Count stock · Review corrections · Apply count · Adjust · Add to buy · Add expiry · Edit batch · Open a new bottle · Finished · Start procedure · Edit usage · Cancel procedure · Opened a new one? · Take new · Mark disposed · Expiring soon · Missing expiry · Alerts · History · Account · Team · Clinic settings · Billing.


## 8. Notifications

In-app alerts (bell) are the source of truth; push and email mirror them.

Push (opt-in at first launch): Out of stock, Expiring within 30 days, Invoice read and ready to review (admin only).

Email digest (admin toggle, Monday 7 am clinic time): To buy count, items expiring in the window, missing expiry count, procedures last week.

Invitation and password emails are transactional and always sent.


## 9. Non-functional requirements

Platforms: iOS 17+, iPhone and iPad, one codebase. Portrait on iPhone; both orientations on iPad.

Performance: lists of 500 products scroll without jank; starting a procedure or applying a count completes under 1 s on a normal connection; invoice reading target under 20 s with progress state.

Concurrency: several users act at once (two assistants each opening a bottle). All stock changes are transactions applied server-side; screens refresh on return to foreground.

Audit: every change carries user, time and reference; nothing is hard-deleted; products are archived.

Privacy: no patient or appointment fields exist anywhere. Invoice images belong to the clinic and can be deleted by an admin. Data is isolated per clinic.

Invoice reading: AI extraction proposes lines; nothing is written until the admin confirms. Low-confidence lines are shown as Possible match or Needs review, never auto-applied.

Billing: Stripe; trial starts at clinic creation; after 3 months the app keeps reading access and blocks writes until a payment method is added (admin sees it on Billing and Home).


## 10. Gaps to close before development

| ID | Gap | Proposed answer |
|---|---|---|
| G1 | The New product sheet has no control to mark a product multi-use; the data model needs it. | Add a Multi-use (bottle, syringe, kit) switch under Units; one design change. |
| G2 | Staff button reads "Report low stock", Admin "Add to buy", same action. | Use "Add to buy" for both unless testing shows staff hesitate. |
| G3 | Low threshold for multi-use products: unopened only, or unopened + open? | Unopened only (an open bottle is already partly used). |
| G4 | Forgot-password, invitation expiry and resend screens are not drawn. | Standard email-link flows; 7-day link; resend from Team. |
| G5 | Trial-ended state (read-only mode) is not drawn. | Banner on Home + Billing card; writes show a sheet pointing to Billing. |
| G6 | Onboarding checklist (first 10 products, first procedure) from v1.0 was removed from the design. | Keep removed; the first Receive delivery seeds products. |

## Appendix · Screen index

| Frame | Screen | Role | Image |
|---|---|---|---|
| f1 | Sign in | Admin / Staff | [f1](frames/f01.png) |
| f2 | Admin · account | Admin | [f2](frames/f02.png) |
| f3 | Admin · clinic | Admin | [f3](frames/f03.png) |
| f4 | Admin · invite team | Admin | [f4](frames/f04.png) |
| f5 | Accept invitation | Staff | [f5](frames/f05.png) |
| f6 | Home · Admin | Admin | [f6](frames/f06.png) |
| f7 | Home · Staff | Staff | [f7](frames/f07.png) |
| f8 | Activity · alerts | Admin / Staff | [f8](frames/f08.png) |
| f9 | Activity · history | Admin / Staff | [f9](frames/f09.png) |
| f10 | Inventory value | Admin / Staff | [f10](frames/f10.png) |
| f11 | Procedures · Admin | Admin | [f11](frames/f11.png) |
| f12 | Procedures · Staff | Staff | [f12](frames/f12.png) |
| f13 | Adjust, then start | Admin / Staff | [f13](frames/f13.png) |
| f14 | From history · edit usage | Admin / Staff | [f14](frames/f14.png) |
| f15 | Edit defaults | Admin | [f15](frames/f15.png) |
| f16 | Inventory · Admin | Admin | [f16](frames/f16.png) |
| f17 | Inventory · Staff | Staff | [f17](frames/f17.png) |
| f18 | Count stock | Admin / Staff | [f18](frames/f18.png) |
| f19 | Low filter | Admin | [f19](frames/f19.png) |
| f20 | Product detail · Admin | Admin | [f20](frames/f20.png) |
| f21 | Product detail · Staff | Staff | [f21](frames/f21.png) |
| f22 | Receive delivery | Admin | [f22](frames/f22.png) |
| f23 | Review invoice | Admin | [f23](frames/f23.png) |
| f24 | Receive manually | Admin | [f24](frames/f24.png) |
| f25 | To buy · Admin | Admin | [f25](frames/f25.png) |
| f26 | To buy · Staff | Staff | [f26](frames/f26.png) |
| f27 | Expiring soon · Admin | Admin | [f27](frames/f27.png) |
| f28 | Expiring soon · Staff | Staff | [f28](frames/f28.png) |
| f29 | Account · Admin | Admin | [f29](frames/f29.png) |
| f30 | Account · Staff | Staff | [f30](frames/f30.png) |
| f31 | Team · Admin | Admin | [f31](frames/f31.png) |
| f32 | Team · Staff | Staff | [f32](frames/f32.png) |
| f33 | Clinic settings | Admin | [f33](frames/f33.png) |
| f34 | Billing | Admin | [f34](frames/f34.png) |
| f35 | Invoices | Admin | [f35](frames/f35.png) |
| f36 | iPad · Home | Admin | [f36](frames/f36.png) |
| f37 | iPad · Procedure | Admin / Staff | [f37](frames/f37.png) |
| f38 | iPad · Review invoice | Admin | [f38](frames/f38.png) |

## Appendix B · Screen specifications

One block per screen: route key, parameters, where it is reached from, and every interactive element with a stable id. Element ids are the contract between design, code and QA: use them as data-testid / accessibility identifiers and in analytics events. Format: screen.element; list rows add the entity id at runtime (inv.row[productId]).


### `signin` · Sign in

Frames f1 · Admin / Staff  
Params: —  
Reached from: App launch when signed out; Account › Sign out  
Sheets: —

| Element id | Behaviour |
|---|---|
| `signin.email` | Email field. Inline error on unknown email. |
| `signin.password` | Password field, show/hide toggle. |
| `signin.submit` | Primary. Disabled until both fields filled. → home |
| `signin.forgot` | Text button → password reset email (G4). |
| `signin.signUpAdmin` | Footer 'Setting up a new clinic? Sign up as admin' → onboard.account |
| `signin.staffNote` | Static: 'Staff join through the invitation email.' |

### `onboard.account` · Create account · step 1 of 3

Frames f2 · Admin  
Params: —  
Reached from: signin.createClinic  
Sheets: —

| Element id | Behaviour |
|---|---|
| `onboard.name` | Full name. |
| `onboard.email` | Email, unique across Dentory. |
| `onboard.password` | Password, min 8 characters. |
| `onboard.continue` | Primary → onboard.clinic |

### `onboard.clinic` · Create clinic · step 2 of 3

Frames f3 · Admin  
Params: —  
Reached from: onboard.account  
Sheets: —

| Element id | Behaviour |
|---|---|
| `onboard.logo` | 72px tap-to-upload placeholder; optional; square crop. |
| `onboard.clinicName` | Required. |
| `onboard.city` | Required. |
| `onboard.country` | Select; drives currency and date format. |
| `onboard.continue` | Primary → onboard.invite. Creates the clinic and starts the trial. |

### `onboard.invite` · Invite team · step 3 of 3

Frames f4 · Admin  
Params: —  
Reached from: onboard.clinic  
Sheets: —

| Element id | Behaviour |
|---|---|
| `onboard.inviteRow[n].name / .email / .role` | Repeating rows; role Staff (default) or Admin. |
| `onboard.addRow` | Adds an empty row. |
| `onboard.sendInvites` | Primary. Sends one email per valid row → home |
| `onboard.skip` | Text button → home without inviting. |

### `invite.accept` · Accept invitation

Frames f5 · Staff  
Params: token  
Reached from: Email link (valid 7 days)  
Sheets: —

| Element id | Behaviour |
|---|---|
| `invite.clinic` | Clinic name and 'Invited by {admin}'. |
| `invite.name` | Prefilled from the invitation, editable. |
| `invite.password` | New password. |
| `invite.submit` | Primary → home. Expired token shows 'Ask your admin to resend.' |

### `home` · Home

Frames f6 · f7 · f36 · Admin / Staff  
Params: —  
Reached from: Tab 1; after sign-in  
Sheets: —

| Element id | Behaviour |
|---|---|
| `home.header.date / .clinic` | Eyebrow date, clinic name (display title). |
| `home.header.bell` | → activity?seg=alerts. Red dot when unread alerts > 0. |
| `home.header.account` | Generic profile icon → more |
| `home.tile.toBuy` | Count of To buy items; warning color, ink when 0 → order |
| `home.tile.expiring` | Batches within the clinic window; danger → expiring |
| `home.tile.missingExpiry` | Products with undated quantity; info → inv?filter=Missing expiry |
| `home.procedure.start` | Primary button on dark card → proc |
| `home.procedure.latest` | Name, when, 'N supplies · by' of the most recent procedure event. |
| `home.procedure.editUsage` | → procDetail?eventId=…&mode=editing |
| `home.tile.inventoryValue` | Σ qty × unit cost → value |
| `home.tile.atRisk` | Value expiring within 90 days → expiring |
| `home.receive` | Admin only. Row 'Receive delivery · Photo, PDF or manual. You confirm every line.' → receive |

### `activity` · Activity

Frames f8 · f9 · Admin / Staff  
Params: seg = alerts | history; filter  
Reached from: home.header.bell  
Sheets: —

| Element id | Behaviour |
|---|---|
| `activity.seg` | Segmented Alerts / History. |
| `activity.alert[id]` | Dot (status color), sentence, when. Tap deep-links; clears when resolved. |
| `activity.filter` | Chips All, Receiving, Procedures, Counts, Adjustments (history only). |
| `activity.day` | Day group eyebrow (Today, Yesterday, date). |
| `activity.row[txId]` | Subject, reason line, 'Name · time', delta right-aligned. Read-only. |

### `value` · Inventory value

Frames f10 · Admin / Staff  
Params: —  
Reached from: home.tile.inventoryValue  
Sheets: —

| Element id | Behaviour |
|---|---|
| `value.total` | Large total with 'at last unit cost'. |
| `value.row[category]` | Category, product count, value. Tap → inv filtered by category. |

### `proc` · Procedures

Frames f11 · f12 · Admin / Staff  
Params: —  
Reached from: Tab 3; home.procedure.start  
Sheets: —

| Element id | Behaviour |
|---|---|
| `proc.addTemplate` | Admin only, header → procEdit?new |
| `proc.template[id]` | Name, 'N items', warning line only when short → procDetail?templateId |
| `proc.template[id].edit` | Admin only pencil → procEdit?templateId |
| `proc.note` | Static note under the list. |
| `proc.history[eventId]` | Newest first: name, 'date · N items · by' → procDetail?eventId |

### `procDetail` · Procedure

Frames f13 · f14 · f37 · Admin / Staff  
Params: templateId | eventId; mode = new | done | editing  
Reached from: proc.template, proc.history, home.procedure.editUsage  
Sheets: addItem, cancelProcedure

| Element id | Behaviour |
|---|---|
| `procDetail.summary` | 'N supplies' + shortage count (new) or 'N items deducted · date · by' (done). |
| `procDetail.item[productId].dec / .inc` | 40px steppers; min 0; value blue when ≠ default. |
| `procDetail.item[productId].remove` | X removes the row (new/editing). |
| `procDetail.item[productId].warning` | '0 will remain' (warning) or 'Not available · N in stock' (danger); otherwise absent. |
| `procDetail.addItem` | Round + bottom-right of the list → sheet addItem |
| `procDetail.bottles.info` | (i) → toast explaining Take new. |
| `procDetail.bottle[productId].takeNew` | Toggle. On: adds product to supplies with qty 1, sub 'Will take 1 from stock · N unopened left'. None unopened → toast 'Out of stock'. |
| `procDetail.start` | mode new. 'Start procedure · N items'. Deducts, opens bottles, records event → proc + toast |
| `procDetail.editUsage` | mode done → mode editing |
| `procDetail.save` | mode editing. Writes the difference → mode done + toast |
| `procDetail.discard` | mode editing → mode done, no change |
| `procDetail.cancel` | mode done, danger text → sheet cancelProcedure |

### `procEdit` · Edit defaults

Frames f15 · Admin  
Params: templateId | new  
Reached from: proc.addTemplate, proc.template.edit  
Sheets: addItem

| Element id | Behaviour |
|---|---|
| `procEdit.name` | Template name; 'Untitled procedure' if empty. |
| `procEdit.item[productId].dec / .inc / .remove` | Default quantity; multi-use products default 0. |
| `procEdit.addItem` | Round + → sheet addItem |
| `procEdit.save` | Primary → proc + toast |
| `procEdit.delete` | Text danger (existing template) → confirm; past events keep their data. |

### `inv` · Inventory / Count

Frames f16 – f19 · Admin / Staff  
Params: mode = browse | count; filter; q  
Reached from: Tab 2; home.tile.missingExpiry; product.count  
Sheets: newProduct, reviewCount, cancelCount

| Element id | Behaviour |
|---|---|
| `inv.countStock` | Header button (clipboard-list) → mode count |
| `inv.search` | Filters rows by name as you type. |
| `inv.filter` | Chips All, Low, Expiring, Missing expiry, Healthy. |
| `inv.row[productId]` | Name, caption, status badge → product?productId (browse) |
| `inv.newProduct` | Admin, browse only. Round + bottom-right → sheet newProduct |
| `inv.count.cancel` | Header X. Changes pending → sheet cancelCount, else → mode browse |
| `inv.count.row[productId].dec / .inc / .value` | Counted quantity; blue when ≠ estimate; multi-use counts unopened only. |
| `inv.count.review` | 'Review · N corrections'; disabled when N = 0 → sheet reviewCount |

### `product` · Product detail

Frames f20 · f21 · Admin / Staff  
Params: productId  
Reached from: inv.row, alerts, expiring.viewProduct, order rows  
Sheets: adjust, batch, newProduct(edit), deleteProduct

| Element id | Behaviour |
|---|---|
| `product.edit` | Admin, header text → sheet newProduct (edit mode) |
| `product.status` | Badge per §5. |
| `product.quantity` | 'System estimate' number + unit; Minimum, Target; 'N used in 30 days · Counted date'; 'Recommended: add N' when Low. |
| `product.adjust` | Tertiary → sheet adjust |
| `product.addToBuy` | Primary (Staff label 'Report low stock'). Adds with suggested qty; toast with Undo. |
| `product.batch[batchId]` | Date bold, 'in N days' colored, qty, lot mono. Tap → sheet batch (edit) |
| `product.addExpiry` | Always shown under the Expiry card → sheet batch (new). Total line 'N of M tracked'. |
| `product.bottle[openId].finished` | Removes the open item; toast. |
| `product.openNewBottle` | Disabled when unopened = 0. Moves 1 unopened → open under current user. |
| `product.history[txId]` | Delta, reason, when. |
| `product.delete` | Admin, danger text → sheet deleteProduct |

### `receive` · Receive delivery

Frames f22 · Admin  
Params: —  
Reached from: home.receive.scan; order (Ordered segment)  
Sheets: —

| Element id | Behaviour |
|---|---|
| `receive.photo` | Dark card → camera → invoice?source=camera |
| `receive.upload` | File picker (PDF, image) → invoice?source=file |
| `receive.manual` | → manual |
| `receive.waiting[itemId]` | Ordered items: name, 'supplier · ordered date', qty. Reference only. |

### `invoice` · Review invoice

Frames f23 · f38 · Admin  
Params: invoiceId; state = reading | review  
Reached from: receive.photo / upload; alert 'Invoice ready'  
Sheets: newProduct(invoice), match

| Element id | Behaviour |
|---|---|
| `invoice.header` | 'Supplier · number · total' once read. |
| `invoice.reading` | Placeholder, 'Reading invoice', 'Usually under 20 seconds', link → manual |
| `invoice.banner` | 'AI read N lines. Check each one, then confirm.' |
| `invoice.line[n].raw / .state` | Raw text (mono) and badge Matched · Possible match · New product · Needs review · Created · Skipped. Unresolved lines have an ink hairline. |
| `invoice.line[n].a / .b` | Primary / tertiary pair: Yes, match · No, create new; Add new · Pick existing; Ignore · Pick product. |
| `invoice.line[n].lot / .expiry` | On Matched and Created lines; optional; skipping flags Missing expiry. |
| `invoice.summary` | 'N of M lines will increase inventory.' or 'Resolve every line to continue.' |
| `invoice.confirm` | 'Confirm & receive'. Disabled until all lines resolved. Converts packs, stores cost, creates batches, marks To buy items Received → inv + toast (Undo) |

### `manual` · Receive manually

Frames f24 · Admin  
Params: productId (optional)  
Reached from: receive.manual; product (Admin); invoice.reading  
Sheets: pickProduct, newProduct

| Element id | Behaviour |
|---|---|
| `manual.product` | Tap → sheet pickProduct. Empty state before a pick. |
| `manual.qty` | In the received unit; caption shows conversion 'Current 1 → after 5 kits'. |
| `manual.cost` | Cost per received unit; optional. |
| `manual.lot / .expiry` | Optional; expiry month picker. |
| `manual.receive` | Primary; disabled until product and qty → inv + toast (no Undo) |

### `order` · To buy

Frames f25 · f26 · Admin / Staff  
Params: seg = toBuy | ordered | received  
Reached from: Tab 4; home.tile.toBuy; product.addToBuy  
Sheets: addOrder

| Element id | Behaviour |
|---|---|
| `order.seg` | 'To buy · N', 'Ordered · N', 'Received · N'. |
| `order.row[itemId].select` | Admin, To buy segment. Checkbox; all selected by default. |
| `order.selectionBar` | 'N of M selected · Clear'. |
| `order.row[itemId].dec / .inc` | Quantity to buy; both roles. |
| `order.row[itemId].remove` | Swipe or X removes a manually added item. |
| `order.add` | Text 'Add item' → sheet addOrder |
| `order.markOrdered` | Admin. 'Mark N as ordered' (N = selected); disabled only when 0 selected → selected items move to Ordered with today's date; toast |
| `order.ordered[itemId]` | 'N ordered date · supplier'. No action; received via invoice. |
| `order.received[itemId]` | History row. |

### `expiring` · Expiring soon

Frames f27 · f28 · Admin / Staff  
Params: window = 30 | 60 | 90  
Reached from: home.tile.expiring / .atRisk; alerts  
Sheets: dispose

| Element id | Behaviour |
|---|---|
| `expiring.seg` | 30 / 60 / 90 days. |
| `expiring.summary` | 'N products · $X at risk within W days.' |
| `expiring.card[batchId]` | Name, 'qty · lot · date', days (danger ≤ 30), value. |
| `expiring.card[batchId].view` | → product?productId |
| `expiring.card[batchId].dispose` | Admin → sheet dispose |

### `more` · Account

Frames f29 · f30 · Admin / Staff  
Params: —  
Reached from: home.header.account  
Sheets: —

| Element id | Behaviour |
|---|---|
| `more.user` | Profile icon, name, 'Role · Clinic'. |
| `more.team` | → team |
| `more.settings` | Admin → settings |
| `more.billing` | Admin → billing |
| `more.export` | Admin. Starts CSV export; toast. |
| `more.help` | Opens help centre. |
| `more.signOut` | Danger text → signin |

### `team` · Team

Frames f31 · f32 · Admin / Staff  
Params: —  
Reached from: more.team  
Sheets: invite

| Element id | Behaviour |
|---|---|
| `team.invite` | Admin, header → sheet invite |
| `team.member[userId]` | Initials, name, email, role. Pending: 'Invited · date'. |
| `team.member[userId].menu` | Admin: Change role, Resend invitation, Remove. Last Admin cannot be removed. |

### `settings` · Clinic settings

Frames f33 · Admin  
Params: —  
Reached from: more.settings  
Sheets: —

| Element id | Behaviour |
|---|---|
| `settings.logo` | Tap to replace. |
| `settings.clinicName / .city / .country` | Editable. |
| `settings.expiryWarning` | Select: 30, 60 and 90 days · 60 and 90 days · 90 days only. |
| `settings.digest` | Switch; weekly Monday 7 am. |
| `settings.save` | Header text → toast 'Settings saved' |

### `billing` · Billing

Frames f34 · Admin  
Params: —  
Reached from: more.billing  
Sheets: billingEmails

| Element id | Behaviour |
|---|---|
| `billing.trial` | Dark card: 'Free trial', 'N days left', 'Ends date'. |
| `billing.price` | '$99 per clinic / month after the trial' or '$49.50 · 50% lifetime promotion'. |
| `billing.paymentMethod` | → Stripe card form; shows last 4 digits when set. |
| `billing.invoices` | → invoices |
| `billing.emails` | Count → sheet billingEmails |

### `invoices` · Invoices

Frames f35 · Admin  
Params: —  
Reached from: billing.invoices  
Sheets: —

| Element id | Behaviour |
|---|---|
| `invoices.empty` | 'No invoices yet' until the first charge. |
| `invoices.row[id]` | Date, amount, status, PDF. |

## Appendix C · Sheets

| Sheet key | Fields and actions | Result |
|---|---|---|
| `adjust` | Title 'Adjust inventory'. Caption 'System estimate N unit. A reason is recorded in history.' Actual quantity (number, unit suffix); Reason select: Physical count, Expired, Damaged, Waste, Missing, Returned, Data correction, Other; 'Save adjustment'. | Adjustment transaction; toast with Undo |
| `batch` | Title 'Add expiry' or 'Edit batch'; product name. Expires (month); How many (unit suffix); Lot (optional, free text); 'Save'. Both roles. | Batch created or updated |
| `newProduct` | Title 'New product' / 'Edit product'. From an invoice: info banner 'From invoice: {raw}. Name and unit are suggested.' Name; Category; Units: Counted in, Received as, pack size question + conversion sentence; Multi-use switch (G1); Minimum; Target; micro 'Quantity, expiry and lot are entered on the receiving form.' CTA: Create product · Save changes · Create and use for this line. Back chevron when opened from pickProduct. | Product created or updated |
| `deleteProduct` | 'Delete {name}?' 'N units still in stock. The product and its history are archived, not erased. It disappears from Inventory, To buy and procedures.' Danger 'Delete product' · 'Keep'. | Archived → inv + toast |
| `addItem` | 'Add item'. Search; 360px scrolling list: name, 'N unit in stock' (multi-use: 'N unopened · N open'); + per row. Already-added products hidden. | Row appended with qty 1 |
| `cancelProcedure` | 'Cancel {name}?' Warning box 'N items will be returned to inventory. Stock levels update immediately.' Required note 'Why is it cancelled?'; micro 'Recorded in Activity with your name.' Danger 'Cancel procedure' disabled until note · 'Keep'. | Cancellation transactions → proc + toast |
| `reviewCount` | 'Review corrections'. Rows 'name · location · 43 → 41' each with Undo; empty text when none. 'Apply count · N corrections' · 'Back to counting'. | Count transactions → browse + toast (no Undo) |
| `cancelCount` | 'Discard this count?' 'N changes. Inventory stays as it is.' Danger 'Discard count' · 'Keep counting'. | mode browse, nothing written |
| `pickProduct` | 'Choose product' + 'New' text button. Search; 360px list with check on the selected row. | manual.product set |
| `match` | 'Which product is this?' Raw invoice text (mono). Search; 360px list; tap picks. | Line becomes Matched |
| `addOrder` | 'Add to To buy'. Search; list of products not already on the list; + per row. | Item added with suggested qty |
| `dispose` | 'Mark disposed'. '{name} · lot X. Removed with reason Expired.' Quantity disposed (default batch qty). Danger 'Mark disposed' · 'Keep'. | Disposal transaction; toast with Undo |
| `invite` | 'Invite a teammate'. Name; Email; Role (Staff, Admin); 'Send invitation'. | Pending member; toast |
| `billingEmails` | 'Billing emails'. 'Invoices and receipts go to every address here.' List (first = Admin, not removable; X on others); Add email + 'Add'; 'Done'. | Clinic billing emails updated |
