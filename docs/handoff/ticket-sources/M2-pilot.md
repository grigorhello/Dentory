# M2 · Clinic pilot: receiving, To buy, expiry and activity

## MS-126 · Receive delivery: choose how
meta: milestone=M2; priority=P0; type=feature; area=receiving; size=2; frames=f22; screens=receive; prd=§6.5; depends=MS-103

### Screen (f22), Admin only (reached from Home `home.receive`)
- Pushed title "Receive delivery".
- Three option cards: `receive.photo` dark ink card "Take a photo · Invoice or packing slip." (Camera icon) → VisionKit document scanner (`VNDocumentCameraViewController` wrapped in `UIViewControllerRepresentable`, multi-page with automatic edge detection; fall back to `PhotosPicker` when the scanner is unavailable) → upload → Review invoice in reading state (MS-129); `receive.upload` "Upload PDF or image · From files or email." (FileUp icon) → `.fileImporter` (PDF, JPG, PNG, HEIC, max 20 MB) → same; `receive.manual` "Receive manually · No invoice, or a single item." (Pencil) → MS-127.
- Micro under the cards: "Nothing affects inventory until you confirm."
- Eyebrow "WAITING FOR DELIVERY" + list `receive.waiting[itemId]` of To buy items with status Ordered: name, "{supplier} · ordered {date}", quantity right. Reference only (no tap action). Hidden when empty.
- Invoices still in reading or ready state appear above Waiting as "Continue reviewing · {supplier or 'Invoice'} · {time}" rows → Review invoice.

### Acceptance criteria
- [ ] Matches f22. Staff cannot reach this screen (no entry point, RPC denied).

## MS-127 · Receive manually
meta: milestone=M2; priority=P0; type=feature; area=receiving; size=3; frames=f24; screens=manual; prd=§6.5 Receive manually, Appendix C pickProduct; depends=MS-126,MS-106,MS-117

### Screen (f24), Admin only
- `manual.product` select-style field "Choose a product" → sheet `pickProduct`: title "Choose product" + text button "New" (→ New product sheet, MS-117, with back chevron to the picker), search, 360 px list with a check on the selected row. Route param `productId` preselects.
- `manual.qty` Quantity in the received unit (pack unit when the product has one, label "Quantity (boxes)"), caption with conversion and effect: "Current 1 → after 5 kits" (or "5 boxes = 250 cartridges · Current 54 → after 304").
- `manual.cost` Cost per unit (currency prefix, per received unit; optional).
- `manual.lot` Lot (optional), `manual.expiry` Expiry (month picker, optional).
- Pinned `manual.receive` primary "Receive", disabled until product and quantity > 0.
- Result: `stock_receive` (converted to counted units, cost per counted unit = cost / pack size), matching To buy items (to_buy or ordered) for the product move to Received → Inventory + toast "Received · {name} +{qty} {unit}" (no Undo).
- For multi-use products the quantity is unopened units.

### Acceptance criteria
- [ ] Matches f24. Receiving 5 boxes of a 50-pack product adds 250 to a batch with the given lot/expiry and updates last unit cost.

## MS-128 · To buy list
meta: milestone=M2; priority=P0; type=feature; area=reorder; size=5; frames=f25,f26; screens=order; prd=§6.6, §5 To buy auto-add, Appendix C addOrder; depends=MS-103,MS-106

A shopping list the clinic takes to its supplier. The app never places orders; avoid wording that implies it does.

### Rules
- Auto-add when a product becomes Low or Out of stock and it has no item in To buy or Ordered; suggested qty = target − current (min 1), recalculated on every stock change until the item is marked Ordered, unless someone edited the quantity (`qty_edited`).
- Anyone can add by hand (Product detail "Add to buy" or here). Manual items can be removed; auto items can be removed too, but they come back only after the product goes back above minimum and drops again.
- Receiving the product (invoice or manual) marks its To buy or Ordered item Received with the date.

### Screen (To buy tab, f25 Admin, f26 Staff)
- Root title "To buy". `order.seg` segmented control: "To buy · N", "Ordered · N", "Received · N".
- **To buy** segment rows `order.row[itemId]`: name, "Current 1 · target 5 · Patterson" (supplier only when known), stepper `order.row[itemId].dec / .inc` (both roles), Admin checkbox `order.row[itemId].select`. All items start selected. Bar `order.selectionBar` "3 of 3 selected" + text "Clear" (Clear unticks all; when none selected it reads "Select all").
- Remove: swipe left on a row → "Remove" (`order.row[itemId].remove`).
- `order.add` text "+ Add item" → sheet `addOrder`: title "Add to To buy", search, products not already on the list, + per row → added with suggested qty (target − current, min 1).
- Admin pinned `order.markOrdered` primary "Mark N as ordered" (N = selected), disabled only when 0 selected → selected items move to Ordered with today's date, toast "Marked as ordered · N items" (no Undo). Staff: no checkboxes, no pinned button (f26).
- **Ordered** rows `order.ordered[itemId]`: name, "{qty} ordered {date} · {supplier}". No per-row receive; deliveries are received from the invoice which moves them automatically.
- **Received** rows `order.received[itemId]`: "Received {date} · {supplier}", newest first, last 90 days.
- Empty segment: EmptyState "Nothing here yet."
- Tab badge (MS-103) = To buy count.

### Acceptance criteria
- [ ] Matches f25 and f26 with the demo seed.
- [ ] Starting a procedure that makes a product Low adds it with the right quantity; a second deduction updates the quantity; marking Ordered freezes it.

## MS-129 · Read invoices with AI
meta: milestone=M2; priority=P0; type=feature; area=invoice-ai; size=8; frames=f23,f38; screens=invoice; prd=§6.5 Reading state, §9 Invoice reading; depends=MS-126,MS-104

### Goal
Turn a photo or PDF of a supplier invoice into proposed lines in under 20 seconds, server-side, without touching inventory.

### Flow
1. App uploads the file(s) to Storage `invoices/{clinic_id}/{invoice_id}/page-n.(jpg|pdf)` and creates `invoices` row status `reading` → navigates to Review invoice in reading state.
2. Reading state UI (`invoice.reading`): document placeholder (Skeleton), "Reading invoice", caption "Usually under 20 seconds", text link "Receive manually instead" → MS-127. The user may leave; when ready an alert "Delivery read and waiting for review" appears (bell) and a push for admins (MS-144).
3. Edge Function `extract_invoice` (triggered by the insert, or called by the app and continued with `EdgeRuntime.waitUntil`): sends the images/PDF to the Claude API (current Claude Sonnet model; load the `claude-api` skill before writing this code for model id, PDF and image input, and structured outputs) with a strict JSON schema:
   `{ supplier, invoice_number, invoice_date, currency, total, lines: [{ raw, qty, unit, unit_price, line_total, lot?, expiry? , kind: product|fee }] }`.
4. Matching (server, deterministic, no AI): for each product line, try in order (a) `supplier_aliases` exact normalized raw text → Matched; (b) normalized name similarity (pg_trgm) ≥ 0.75 to an active product → Matched, 0.45–0.75 → Possible match (with suggested product); (c) else New product with a suggested name and unit from the raw text. Fee/surcharge/shipping/tax lines → Needs review. Low-confidence lines are never auto-applied.
5. Save `invoice_lines`, set invoice status `ready` (or `failed` with a reason; UI then shows Notice danger "We couldn't read this invoice. Try a clearer photo or receive manually." with both actions).

### Privacy
No patient data is expected; the prompt instructs the model to ignore any personal data. Files stay in the clinic's bucket. Do not log invoice contents.

### Acceptance criteria
- [ ] A fixture set of 5 invoices (PDF and photo, committed under `supabase/functions/extract_invoice/fixtures/`, no real customer data) extracts supplier, number, total and lines; a test asserts the matching states for the demo catalog (SEPTO 4% 1:100K 50/BX → Matched Septocaine; ENDO FILE KIT 15-40 21MM → Possible match; TEMPBOND NE 1PK → New product; HANDLING / FUEL SURCHARGE → Needs review).
- [ ] p50 under 20 s on the fixtures; timeout at 60 s sets status failed.
- [ ] No inventory rows change during extraction.

## MS-130 · Review invoice lines
meta: milestone=M2; priority=P0; type=feature; area=invoice-ai; size=5; frames=f23,f38; screens=invoice; prd=§6.5 Review invoice, Appendix C match, newProduct; depends=MS-129,MS-117

### Screen (state review, f23; iPad f38), Admin only
- Header title "Review invoice", subtitle `invoice.header` "Patterson Dental · INV-10092 · $449.00".
- `invoice.banner` info Notice "AI read N lines. Check each one, then confirm."
- One card per line `invoice.line[n]`: raw description in monospace (`.raw`), state badge (`.state`), main line and qty/price "5 boxes · $49.80". Unresolved lines (Possible match, New product, Needs review) have an ink hairline border and cream page background; resolved ones lose the border.
  - **Matched**: product name; Expiry (month) and Lot (optional, "Free text") inputs (`.expiry`, `.lot`); micro "No expiry → listed under Missing expiry."
  - **Possible match**: "Is this {product}?" + "Name differs slightly from your product." Buttons `.a` primary "Yes, match" → Matched; `.b` tertiary "No, create new" → New product sheet prefilled.
  - **New product**: "Not in your inventory" + "No product with this name exists yet." `.a` "Add new" → New product sheet (MS-117) with the invoice banner, name and unit suggested, CTA "Create and use for this line" → line becomes Created; `.b` "Pick existing" → sheet `match`.
  - **Needs review** (fees): "Looks like a fee, not a product" + "Fees and surcharges should not go into stock." `.a` tertiary "Ignore" → Skipped ("Ignored · not added to inventory"); `.b` "Pick product" → sheet `match`.
  - **Created**: "{name} · new product", lot/expiry inputs. **Skipped**: muted, "Ignored · not added to inventory", text "Undo" to reopen the line.
- Sheet `match`: title "Which product is this?", raw text (mono), search, 360 px list ("{category} · {qty} {unit}"); tap → line Matched.
- Any resolved line can be reopened by tapping its badge (back to its original state).
- Pinned bar: caption `invoice.summary` "N of M lines will increase inventory." or "Resolve every line to continue."; primary `invoice.confirm` "Confirm & receive" (Check icon) disabled until every line is resolved (MS-131).
- Progress is saved per line on the server so the admin can leave and come back.
- Admin can discard the invoice from the header "…" menu: "Discard invoice" → confirm sheet → status discarded, file deleted.

### Acceptance criteria
- [ ] Matches f23 (both scroll positions) with the demo invoice; on iPad matches f38.
- [ ] Each state transition works and survives leaving and reopening the screen.

## MS-131 · Confirm and receive an invoice
meta: milestone=M2; priority=P0; type=feature; area=receiving; size=3; frames=f23; screens=invoice; prd=§6.5 Confirm; depends=MS-130,MS-106,MS-128

### Behaviour of `invoice.confirm`
- One RPC `invoice_confirm(invoice_id)` in a single transaction: converts packs to counted units (5 boxes → 250 cartridges using the product pack size; if the invoice unit is the counted unit, no conversion), stores unit cost per counted unit (`unit_price / pack_size`), creates or adds to batches with the line's lot and expiry (no expiry → undated), writes receiving transactions with ref "Invoice {number}", marks matching To buy and Ordered items Received, learns `supplier_aliases` from every Matched or Created line, sets product supplier when empty, sets invoice status confirmed.
- → Inventory tab + toast "Delivery received · Inventory increased for N products." with Undo (reverses the whole action within the Undo window, D10; the invoice returns to ready).
- Opening a confirmed invoice later (from Activity) shows it read-only.

### Acceptance criteria
- [ ] Confirm on the demo invoice increases Septocaine by 250, creates the Temp-Bond NE product with 1 unit, ignores the surcharge, and moves Endo file kit from Ordered/To buy to Received.
- [ ] Next invoice from the same supplier with the same raw text matches automatically (alias learned).
- [ ] Undo restores every quantity.

## MS-132 · Expiring soon and Mark disposed
meta: milestone=M2; priority=P0; type=feature; area=lots-expiry; size=3; frames=f27,f28; screens=expiring; prd=§6.7, Appendix C dispose; depends=MS-107,MS-106

### Screen (f27 Admin, f28 Staff), reached from Home tiles and alerts
- Pushed title "Expiring soon". `expiring.seg` segmented "30 days · 60 days · 90 days" (route param `window`, default the clinic's largest threshold).
- `expiring.summary` "2 products · $186 at risk within 90 days."
- One card per batch `expiring.card[batchId]`: name, "{qty} {unit} · lot {lot} · {date}", right "{N} days" (danger ≤ 30, warning otherwise; "Expired" when past, danger) and value "$82" (qty × last unit cost). Buttons: `expiring.card[batchId].view` tertiary "View product" → Product detail; Admin `expiring.card[batchId].dispose` text "Mark disposed" → sheet. Sorted soonest first; expired batches first.
- Empty: EmptyState "Nothing expires in this window."

### Sheet (`dispose`), Admin
Title "Mark disposed", caption "{name} · lot {lot}. Removed with reason Expired." Quantity disposed (default: the batch quantity, max the batch quantity). Danger "Mark disposed" · text "Keep". Result: `stock_dispose` → toast "Disposed · {qty} {unit} {name}" with Undo.

### Acceptance criteria
- [ ] Matches f27/f28 with the demo seed.
- [ ] Disposing the full batch removes the card and updates the Home tile and value at risk.

## MS-133 · Activity: alerts and the bell
meta: milestone=M2; priority=P0; type=feature; area=alerts; size=3; frames=f8,f6; screens=activity; prd=§6.8, §5 Alerts; depends=MS-107,MS-114

### Screen (f8), both roles, opened from the bell
- Pushed title "Activity", `activity.seg` segmented "Alerts · N" / "History".
- `activity.alert[id]` rows: colored dot (danger for out of stock and ≤ 30 days, warning for low and expiring, info for missing expiry and invoice ready), one sentence, time ("Today · 8:40 AM", "Yesterday"), chevron. Sentences:
  - Out of stock: "{name} is out of stock."
  - Low: "{name} is low · {qty} left, minimum {min}."
  - Expiring: "{name} expires in {N} days." (lot when several batches)
  - Missing expiry: "{name} is missing expiry information."
  - Invoice ready: "Delivery from {supplier} is read and waiting for review." (Admin only)
- Tap deep-links: product alerts → Product detail; expiring → Product detail; invoice → Review invoice.
- Alerts clear themselves when the condition is gone (MS-106/107); no dismiss action.
- Bell red dot: shown when any open alert has `opened_at` > the user's `alert_reads.last_seen_at`; opening the Alerts segment updates last_seen_at.
- Empty: EmptyState "Nothing needs attention."

### Acceptance criteria
- [ ] Matches f8. Resolving a condition (receive the out-of-stock product) removes its alert on refresh.

## MS-134 · Activity: history
meta: milestone=M2; priority=P1; type=feature; area=alerts; size=3; frames=f9; screens=activity; prd=§6.8 History, §9 Audit; depends=MS-133

### History segment (f9), both roles
- `activity.filter` chips: All, Receiving, Procedures, Counts, Adjustments (Adjustments includes disposals and bottle open/finish; Procedures includes cancellations and edits).
- `activity.day` groups: "TODAY", "YESTERDAY", then "SEP 30".
- `activity.row[txId]`: subject (product, or the procedure name for procedure rows grouped by event: "Root canal" with delta "−6" = sum), reason line ("Invoice INV-10092", "Procedure started", "Physical count", "Damaged", "Edited usage", "Cancelled · {note}", "Opened a new bottle", "Finished"), "{first name} · {time}" on its own line, delta right (+ success, − danger, "43 → 41" ink for counts). Read-only, no undo (D5: no level rows).
- Infinite scroll, 50 per page. Route param `productId` filters to one product (from Product detail "Show all").

### Acceptance criteria
- [ ] Matches f9 with the demo seed (without the "Full → 50%" row).

## MS-135 · Inventory value
meta: milestone=M2; priority=P2; type=feature; area=reports; size=2; frames=f10; screens=value; prd=§5 Inventory value, Appendix B value; depends=MS-107

### Screen (f10), both roles, from Home `home.tile.inventoryValue`
- Pushed title "Inventory value".
- `value.total` card: large total "$12,420" (at last unit cost), then three mini stats: "Expiring ≤ 90 d" (warning, value at risk), "Used, 30 d" (value of procedure deductions in 30 days), "Received, 30 d" (value received in 30 days). (Decision D7: build as drawn.)
- Eyebrow "BY CATEGORY": `value.row[category]` category, value, share %, thin progress bar; tap → Inventory filtered by that category.
- Eyebrow "HIGHEST VALUE PRODUCTS": top 5 products "{qty} × {unit cost}" and value, chevron → Product detail.
- Products without a unit cost count as $0 and a caption shows "N products have no cost yet."

### Acceptance criteria
- [ ] Matches f10 (both scroll positions); totals equal Σ quantity × last unit cost from the database.

## MS-136 · Pilot readiness pass
meta: milestone=M2; priority=P0; type=chore; area=platform; size=3; frames=; screens=; prd=§7, §9; depends=MS-110,MS-111,MS-112,MS-114,MS-115,MS-116,MS-117,MS-118,MS-119,MS-120,MS-121,MS-122,MS-123,MS-124,MS-125,MS-126,MS-127,MS-128,MS-129,MS-130,MS-131,MS-132,MS-133,MS-134

### Goal
A pilot clinic can use the app daily on real iPhones.

### Action items
- [ ] XCUITest end-to-end flows, run in CI on the iOS simulator against the local seeded Supabase: sign-up → clinic → invite; receive invoice (fixture) → confirm; start procedure with Take new → edit usage → cancel; count stock → apply; To buy → mark ordered → receive; expiring → dispose; Staff login cannot see admin controls.
- [ ] Visual comparison: walk every frame f1–f35 against the app with the demo seed and file a bug for each visible difference that is not covered by a decision in MS-100.
- [ ] Copy check against PRD §7 Vocabulary (exact terms) and Copy rules (sentence case, no exclamation marks, no emoji, no "please").
- [ ] TestFlight internal build (MS-152 covers the store; here only internal testing).
- [ ] One week of internal use with the demo clinic; fix P0/P1 bugs.

### Acceptance criteria
- [ ] All flows green in CI; no open P0 bugs.
