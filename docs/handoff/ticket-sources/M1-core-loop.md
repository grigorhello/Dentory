# M1 · Internal alpha: accounts, inventory and procedures

## MS-110 · Sign in
meta: milestone=M1; priority=P0; type=feature; area=auth; size=2; frames=f1; screens=signin; prd=§6.1; depends=MS-103,MS-105

### User story
As anyone with a MediSave account, I sign in with email and password and land on Home of my clinic.

### Screen (f1)
- Title "MediSave" (display 32), caption "Sign in to your clinic."
- `signin.email` Email field. Inline error under the field on unknown email: "No account with this email."
- `signin.password` Password field with show/hide toggle. Wrong password error: "Wrong password."
- `signin.submit` primary "Sign in", disabled until both fields have text → Home.
- `signin.forgot` text button "Forgot password" → MS-113.
- Footer: "Setting up a new clinic? **Sign up as admin**" (`signin.signUpAdmin` → onboard step 1, MS-111) and static "Staff join through the invitation email." (`signin.staffNote`).
- Do not build "Continue with Google" (decision D4).

### Behaviour
- Supabase Auth email + password. Session persists on device (secure storage); app launch with a valid session goes straight to Home.
- A user with memberships in more than one clinic is out of scope for V1.1; use the first active membership.
- A signed-in user whose membership was revoked sees Sign in with the toast "You no longer have access to this clinic."

### Acceptance criteria
- [ ] Matches `design/frames/f1.png` minus the Google button.
- [ ] Errors render inline; the button shows loading during the call.
- [ ] XCUITest flow: sign in as the demo admin → Home.

## MS-111 · Admin sign-up: account, clinic and team invites
meta: milestone=M1; priority=P0; type=feature; area=onboarding; size=5; frames=f2,f3,f4; screens=onboard.account,onboard.clinic,onboard.invite; prd=§6.1; depends=MS-110,MS-104

### User story
As a practice owner, I create my admin account and my clinic in three short steps, invite my team, and land on Home.

### Step 1 · Account (f2) eyebrow "ADMIN SIGN-UP · STEP 1 OF 3", title "Create your admin account", caption "You will own the clinic workspace and invite the team."
- `onboard.name` Full name, `onboard.email` Work email (unique across MediSave; error "An account with this email already exists. Sign in instead."), `onboard.password` (min 8 characters; hint "At least 8 characters").
- `onboard.continue` primary "Continue →", disabled until valid → step 2. Back chevron returns to Sign in. No Google button (D4).
- Creates the Supabase Auth user and profile. Email confirmation: not required to continue in V1.1 (send a welcome email only).

### Step 2 · Clinic (f3) eyebrow "STEP 2 OF 3", title "Create your clinic"
- `onboard.logo` 72 px tap-to-upload placeholder ("Clinic logo · Tap to upload. Optional, square works best."), square crop via image picker, uploaded to `logos/{clinic_id}/`.
- `onboard.clinicName` (required), `onboard.city` (required), `onboard.country` Select (required; drives currency and date format; default from device locale).
- `onboard.continue` primary "Create clinic →" creates the clinic, the admin membership, the default categories (D13), and sets `trial_ends_at = now() + 3 months`, `subscription_status = trialing` → step 3. No currency or time zone questions.

### Step 3 · Invite team (f4) eyebrow "STEP 3 OF 3", title "Invite your team", caption "Each person gets an email with a link to set their password. You can add more later under Team."
- Repeating rows `onboard.inviteRow[n].email` + `.role` (Staff default, Admin). Two empty rows to start; `onboard.addRow` "+ Another person" adds one. The frame shows Email + Role only; name is optional and filled by the invitee (MS-112).
- `onboard.sendInvites` primary "Send invitations" sends one invite per valid row (MS-112 function) → Home with toast "Invitations sent · They get a link by email."; invalid emails show inline errors and block sending.
- `onboard.skip` text "Skip for now" → Home.

### Acceptance criteria
- [ ] Each step matches its frame.
- [ ] Killing the app after step 2 and reopening resumes at step 3 (clinic exists), never creates a second clinic.
- [ ] SQL/Edge test: a new clinic has an admin membership, categories, trial end date 3 months out.

## MS-112 · Invite teammates and accept an invitation
meta: milestone=M1; priority=P0; type=feature; area=team; size=3; frames=f5,f4,f31; screens=invite.accept; prd=§6.1, G4; depends=MS-111

### Invite (server)
Edge Function `invite_member(clinic_id, email, role, full_name?)`, admin only: creates or refreshes a `memberships` row with status invited, a random token (store only its hash), `invite_expires_at = now() + 7 days`, and sends the email via Resend: subject "{Admin name} invited you to {Clinic} on MediSave", body with one button "Join {Clinic}" linking to `https://{domain}/invite?token=…` (universal link, D12). Resend = same function with a new token (old one stops working).

### Accept invitation screen (f5), Staff
- Eyebrow "INVITATION", title "Join {Clinic}", caption "{Admin} invited you as {Role}. Set a password to finish." (`invite.clinic`).
- `invite.name` Full name (prefilled when the admin gave one, editable), email shown read-only (from the invitation), `invite.password` (min 8).
- `invite.submit` primary "Join clinic" → creates the auth user (or signs in an existing one), sets membership active → Home.
- Expired or used token: screen shows "This invitation has expired. Ask your admin to resend." and a Sign in link.

### Acceptance criteria
- [ ] End-to-end on simulator: admin invites, link opens the app on Join screen, staff lands on Home with Staff role.
- [ ] Token older than 7 days is rejected; resend invalidates the old token.

## MS-113 · Reset a forgotten password
meta: milestone=M1; priority=P1; type=feature; area=auth; size=2; frames=f1; screens=signin; prd=G4; depends=MS-110

Not drawn (gap G4). Build from existing components in the Sign in style.
- From `signin.forgot`: pushed screen "Reset password", caption "We'll email you a link to set a new password.", Email field (prefilled from Sign in), primary "Send link". Always shows the same confirmation (no account enumeration): Notice success "If an account exists for {email}, a link is on its way."
- Link (Supabase recovery, universal link D12) opens "Set a new password": New password (min 8), primary "Save password" → Home with toast "Password updated".
- Expired link: "This link has expired. Send a new one." with a button back to Reset password.

### Acceptance criteria
- [ ] Full flow works on simulator with the local Supabase inbucket mail catcher.

## MS-114 · Home: what needs me today
meta: milestone=M1; priority=P0; type=feature; area=dashboard; size=3; frames=f6,f7,f36; screens=home; prd=§6.2; depends=MS-103,MS-107

### Layout, in this order and nothing else (f6 Admin, f7 Staff)
1. Header: `home.header.date` eyebrow (e.g. "THURSDAY, OCTOBER 2"), `home.header.clinic` clinic name as the 32 px title, `home.header.bell` (Bell icon, red dot when the user has unseen alerts → Activity Alerts, MS-133), `home.header.account` (User icon → Account, MS-137).
2. Eyebrow "NEEDS ATTENTION" and three equal tiles: `home.tile.toBuy` (count of To buy items, warning color) → To buy tab; `home.tile.expiring` (batches within the clinic window, danger) → Expiring soon (MS-132); `home.tile.missingExpiry` (products with undated quantity, info blue) → Inventory filtered Missing expiry. Number turns ink when 0.
3. Procedure card (dark ink, featured): eyebrow "PROCEDURE", `home.procedure.start` primary "Start a procedure" (ClipboardCheck icon) → Procedures tab. Divider, then "LATEST" with date/time right, `home.procedure.latest` name and "N supplies · {first name}", `home.procedure.editUsage` "Edit usage" (Pencil) → that event in editing mode (MS-124). Hide the Latest block when the clinic has no procedures yet.
4. Two value tiles: `home.tile.inventoryValue` "Inventory value" (currency, no cents) → Inventory value (MS-135); `home.tile.atRisk` "At risk, 90 days" → Expiring soon with window 90.
5. `home.receive` Admin only: card "Receive delivery · Photo, PDF or manual. You confirm every line." with Truck icon and chevron → Receive delivery (MS-126). Hidden for Staff (f7).

### Data
One query on `clinic_attention` + latest `procedure_events`; refetch on focus and after any mutation.

### Acceptance criteria
- [ ] With the demo seed, matches `design/frames/f6.png` (Admin) and `f7.png` (Staff).
- [ ] Each tile and row navigates as listed; zero counts render in ink.
- [ ] Trial-ended banner slot exists above the tiles (filled by MS-142).

## MS-115 · Inventory list: browse, search and filter
meta: milestone=M1; priority=P0; type=feature; area=catalog; size=3; frames=f16,f17,f19; screens=inv; prd=§6.4 Inventory list; depends=MS-103,MS-107

### Screen (Inventory tab, mode browse)
- Root title "Inventory" with `inv.countStock` tertiary button "Count stock" (ClipboardList icon) in the header → count mode (MS-121).
- `inv.search` search field, filters rows by name as you type (case and accent insensitive).
- `inv.filter` chips, horizontally scrollable: All, Low, Expiring, Missing expiry, Healthy. Low includes Out of stock (f19). Route param `filter` preselects a chip (from Home tile).
- `inv.row[productId]` rows grouped in one list card: name (14 ink), caption "54 cartridges · Anesthetic" (multi-use: "1 unopened · 2 open · Sterilization"), right status badge. Tap → Product detail. Sorted by status priority then name.
- `inv.newProduct` Admin only: round 56 px + bottom right → New product sheet (MS-117). Staff: no + (f17).
- Empty search: EmptyState "No products match." Empty clinic (Admin): EmptyState "No products yet. Receive a delivery to add them." with a tertiary "Receive delivery".
- Category filter: route param `category` (from Inventory value, MS-135) shows a removable chip with the category name.

### Performance
500 products scroll without jank: FlashList, memoised rows, statuses from `product_status` in one query.

### Acceptance criteria
- [ ] Matches f16 (Admin), f17 (Staff), f19 (Low filter) with the demo seed.
- [ ] Filtering and search combine.

## MS-116 · Product detail
meta: milestone=M1; priority=P0; type=feature; area=catalog; size=5; frames=f20,f21; screens=product; prd=§6.4 Product detail; depends=MS-115

### Layout (f20 Admin, f21 Staff)
- Header: back, subtitle "Category · 1 box = 50 cartridges" (or "Category · unit" without a pack), `product.edit` text "Edit" (Admin only → MS-117 edit mode).
- Title row: product name + `product.status` badge.
- `product.quantity` card: three columns Available (big number + unit), Minimum, Target; below a divider: "System estimate · N {unit} used in 30 days" and right "Counted {date}" (last count transaction; "Never counted" if none). When Low or Out: Notice warning "Recommended: add N {unit}" (N = target − quantity).
- Actions row: `product.adjust` tertiary "Adjust" (SlidersHorizontal) → Adjust sheet (MS-118); `product.addToBuy` primary "Add to buy" (ShoppingCart; both roles, decision G2) → adds to To buy with suggested qty, toast "Added to To buy · {name} · {qty} {unit}" with Undo. If the product is already on the list, the button reads "On To buy" and opens the To buy tab.
- Eyebrow "EXPIRY" + expiry card (MS-119), caption "Tap a batch to edit its expiry, lot or quantity.", `product.addExpiry` "+ Add expiry".
- Bottles card for multi-use products (MS-120).
- Eyebrow "HISTORY": `product.history[txId]` last 20 transactions: delta ("43 → 41" ink for counts, "+4" success, "−2" danger), reason line "{reason or reference} · {first name}", right date. "Show all" opens Activity History filtered to this product.
- `product.delete` Admin only, danger text "Delete product" at the bottom → MS-117 delete sheet.

### Acceptance criteria
- [ ] Matches f20/f21 with the demo seed (Septocaine).
- [ ] Add to buy + Undo leaves the To buy list unchanged.
- [ ] Staff sees no Edit and no Delete product.

## MS-117 · Create, edit and delete products
meta: milestone=M1; priority=P0; type=feature; area=catalog; size=3; frames=f16,f20; screens=inv,product; prd=§6.4 Sheets on this flow, Appendix C newProduct, deleteProduct, G1; depends=MS-116

### New / Edit product sheet (`newProduct`), Admin only
- Title "New product" / "Edit product". When opened from an invoice line (MS-130): info Notice "From invoice: {raw line}. Name and unit are suggested. Check them and add the rest."
- Name (hint "As written on the box", required), Category (select from clinic categories + "New category…").
- Units: "Counted in" (e.g. cartridges, required) and "Received as" (optional, e.g. box). When Received as is set: "How many {counted} in 1 {received}?" (integer ≥ 2) and a plain sentence: "Receive in boxes, count and use in cartridges. 1 box adds 50 cartridges."
- Switch "Multi-use (bottle, syringe, kit)" (G1). Caption: "Tracked as unopened and open items." Changing it on an existing product with stock is blocked with the inline error "Set stock to 0 before changing how it is tracked."
- Stock levels: Minimum ("Alert below"), Target ("Reorder up to"); Target ≥ Minimum.
- Optional: Supplier, Location (free text).
- Micro: "Quantity, expiry and lot are entered on the receiving form."
- CTA: "Create product" · "Save changes" · "Create and use for this line" (invoice). Disabled until a name and unit are entered.
- Result: product created or updated; toast "Product created" / "Changes saved". Changing min/target re-runs `refresh_product`.

### Delete product sheet (`deleteProduct`)
"Delete {name}?" · "{N} {unit} still in stock. The product and its history are archived, not erased. It disappears from Inventory, To buy and procedures." Danger "Delete product" · text "Keep". Result: `archived_at` set, removed from templates and open To buy items, history kept → Inventory + toast "Product deleted".

### Acceptance criteria
- [ ] Pack conversion sentence updates live.
- [ ] Archived products no longer appear in lists, search, add-item sheets or templates, but past procedures and Activity still show their name.

## MS-118 · Adjust a quantity with a reason
meta: milestone=M1; priority=P0; type=feature; area=counts; size=2; frames=f20,f21; screens=product; prd=§6.4 Adjust inventory, Appendix C adjust; depends=MS-116,MS-106

### Sheet (`adjust`), both roles
- Title "Adjust inventory", caption "System estimate {N} {unit}. A reason is recorded in history."
- Actual quantity (number, unit suffix; for multi-use: unopened count, label "Unopened"), Reason select: Physical count, Expired, Damaged, Waste, Missing, Returned, Data correction, Other. "Other" shows a required Note field.
- Primary "Save adjustment", disabled until the quantity differs from the estimate and a reason is chosen.
- Result: `stock_adjust` → toast "Inventory adjusted · {name} {before} → {after}" with Undo (MS-106 `undo_action`).

### Acceptance criteria
- [ ] Adjust then Undo restores the original quantity and both rows appear in History.

## MS-119 · Track expiry per batch: Add expiry and Edit batch
meta: milestone=M1; priority=P0; type=feature; area=lots-expiry; size=3; frames=f20,f21; screens=product; prd=§4 Batch, §6.4 Expiry card, Appendix C batch; depends=MS-116,MS-106

### Expiry card (headline of Product detail)
- Header row Expires · Qty · Lot. Rows sorted soonest first: date in bold ("Dec 1, 2026"; month precision shows "Mar 2027"), pill "in N days" (danger ≤ 30, warning ≤ 90, success beyond, "Expired" when past), quantity, lot in monospace. The soonest batch gets the ink hairline emphasis when it is within the window.
- Total line: "{tracked} of {total} tracked · {n} expire within 90 days", unit on the right. Undated quantity is therefore visible.
- No batches: EmptyState "No expiry dates yet."
- `product.batch[batchId]` tap → sheet Edit batch; `product.addExpiry` → sheet Add expiry.

### Sheet (`batch`), both roles
Title "Add expiry" or "Edit batch", caption product name. Expires (month picker), How many (unit suffix), Lot (optional, free text), primary "Save". Add expiry takes quantity from undated stock first; if more is entered than is undated, the extra is an increase recorded as Data correction (`batch_upsert`, MS-106). Edit batch can change date, lot and quantity.

### Acceptance criteria
- [ ] Adding expiry to all undated quantity clears Missing expiry (status and Home tile update).
- [ ] Batches sorted correctly across years; "Expired" shows for past months.

## MS-120 · Multi-use products: open a new bottle and mark it finished
meta: milestone=M1; priority=P0; type=feature; area=procedures; size=2; frames=f20,f21; screens=product; prd=§4 Open item, §6.4 Bottles card; depends=MS-116,MS-106

Multi-use products (bottles, syringes, kits) are tracked as unopened count + open items with who and when. No level or percentage estimates (D5).

### Bottles card (multi-use only), both roles
- Header "{N} unopened · {N} open".
- One row per open item: "Open · {first name}" and "opened N days ago" ("opened today", "opened yesterday"), right `product.bottle[openId].finished` text button "Finished" → removes the open item, toast "Bottle finished · {name} · {line}".
- `product.openNewBottle` tertiary "Open a new bottle" (label uses the unit: bottle, syringe, kit), disabled when unopened = 0 (the one disabled control allowed, because it is a stock rule, not a role rule). Moves one unopened to open under the current user, toast "{Unit} opened".
- Several people can each have one open.

### Acceptance criteria
- [ ] Opening and finishing write ledger rows (procedure-independent) and update the list row caption "1 unopened · 2 open".

## MS-121 · Count stock with review before applying
meta: milestone=M1; priority=P0; type=feature; area=counts; size=5; frames=f18; screens=inv; prd=§6.4 Count stock, Appendix C reviewCount, cancelCount; depends=MS-115,MS-106

### Count mode (f18), both roles
- Inventory title becomes "Count"; header shows `inv.count.cancel` X instead of the + button; tab bar stays.
- Every row turns into `inv.count.row[productId].dec / .inc / .value` steppers around the current quantity, sub-line "est. 54 cartridges · {location}". Changed values turn blue. Multi-use rows count unopened only, sub-line "Count unopened only".
- Search and filter chips stay available so a drawer or category can be counted alone. Counts persist while filtering.
- Pinned `inv.count.review` primary "Review · N corrections", disabled until at least one value changed.
- Counts survive app backgrounding (keep the draft in a small JSON file until applied or discarded).

### Review corrections sheet (`reviewCount`)
Title "Review corrections"; rows "{name} · {location} · 43 → 41" each with text "Undo" (resets that row). Primary "Apply count · N corrections", text "Back to counting". Apply → `stock_count_apply` (one Count transaction per changed product, "Physical count · {name}") → browse mode + toast "Count applied · N products updated" (no Undo).

### Cancel count sheet (`cancelCount`)
Only when changes are pending: "Discard this count?" · "N changes. Inventory stays as it is." Danger "Discard count" · text "Keep counting". Without changes, X exits silently.

### Acceptance criteria
- [ ] Matches f18. Count three products in different filters, review shows all three, apply writes three transactions and updates "Counted {date}" on Product detail.

## MS-122 · Procedures list and history
meta: milestone=M1; priority=P0; type=feature; area=procedures; size=2; frames=f11,f12; screens=proc; prd=§6.3 Procedures list; depends=MS-103,MS-107

### Screen (Procedures tab)
- Root title "Procedures". Admin: `proc.addTemplate` header "+ Template" → Edit defaults new (MS-125). Staff: none (f12).
- `proc.template[id]` one row per template: name, "N items", and a warning line only when something is short: "1 not available" (danger) when any item's default qty exceeds stock, otherwise "2 will run out" (warning) when items would reach 0. Nothing when all is fine. Tap → Adjust, then start (MS-123). Admin: `proc.template[id].edit` pencil → Edit defaults.
- `proc.note` static: "Starting a procedure deducts its supplies right away. Starter quantities are templates, not clinical recommendations."
- Eyebrow "HISTORY · TAP TO EDIT USAGE": `proc.history[eventId]` every past procedure newest first (paginate 30): name, "{date} · N items · {first name}"; cancelled events show a "Cancelled" caption. Tap → MS-124.
- Empty templates (Admin): EmptyState "No procedures yet." + "+ Template".

### Acceptance criteria
- [ ] Matches f11 (Admin) and f12 (Staff) with the demo seed.

## MS-123 · Adjust, then start a procedure
meta: milestone=M1; priority=P0; type=feature; area=procedures; size=8; frames=f13,f37; screens=procDetail; prd=§6.3 Adjust, then start, Appendix C addItem; depends=MS-122,MS-106,MS-120

The core daily flow: the assistant picks a procedure, corrects the list, starts. Stock changes immediately; mistakes are fixed from history, never blocked up front.

### Screen (mode new, f13; iPad f37)
- Header: template name. `procDetail.summary` "12 supplies · 1 not available. Add or remove items before you start." (variants: "· 2 will reach 0", "· all in stock").
- Card "Supplies for this procedure" / "Qty": per countable row `procDetail.item[productId].dec / .inc` (40 px), quantity in blue when ≠ default, `procDetail.item[productId].remove` X. Sub-line only when needed `procDetail.item[productId].warning`: "0 will remain" (warning) or "Not available · N in stock" (danger).
- `procDetail.addItem` "+ Add item" at the bottom of the list → sheet `addItem`: title "Add item", search, 360 px list of products not already in the list (name, "N unit in stock"; multi-use "N unopened · N open"), + per row; tap appends with qty 1.
- Eyebrow "OPENED A NEW ONE?" with `procDetail.bottles.info` (i) → toast "Tap Take new when you open a fresh bottle, syringe or kit from stock. Using an already open one changes nothing."
- One row per multi-use product in the template: name, "N open · N in stock". `procDetail.bottle[productId].takeNew` outlined "Take new" toggle: on = filled blue, the product is added to the supplies list with qty 1 and the sub-line becomes "Will take 1 from stock · N unopened left"; tap again removes it. Nothing unopened → toast "Out of stock", no change. These rows have no remove X; which products appear is defined by the template.
- Pinned `procDetail.start` primary "Start procedure · N items" (N = total quantity of all rows incl. take-new; count only).
- Back chevron ("Cancel procedure" before start) simply goes back; nothing changed.

### Start
`stock_procedure_start` → returns to Procedures with toast "{name} started · N items deducted" (no Undo). Stock may go negative; it shows as Out of stock, never blocked. Under 1 s on a normal connection (optimistic UI allowed, rollback on failure with the error toast).

### Acceptance criteria
- [ ] Matches f13 (both scroll positions) with the demo seed.
- [ ] Start with a short item creates the event, quantity goes negative, product shows Out of stock, To buy auto-adds it.
- [ ] Take new on Surface disinfectant moves 1 unopened to an open item tagged with the user and today.
- [ ] XCUITest flow: Procedures → Root canal → +1 Septocaine → Start → toast.

## MS-124 · Procedure from history: edit usage or cancel
meta: milestone=M1; priority=P0; type=feature; area=procedures; size=5; frames=f14; screens=procDetail; prd=§6.3 From history, Appendix C cancelProcedure; depends=MS-123

### Read-only view (mode done, f14), both roles
- Banner `procDetail.summary` (success-tinted Notice) "10 items deducted · Oct 1 · 3:14 PM · Sarah".
- List titled "Supplies used" with a "Used" column; multi-use rows read "Opened a new bottle" or "Used from open bottle".
- Pinned bottom area: `procDetail.editUsage` full-width tertiary "Edit usage" (Pencil) → editing mode, and below it `procDetail.cancel` text button "Cancel procedure" → sheet (f14 renders it in ink; use danger text color per Appendix B).
- Cancelled events: read-only, Notice "Cancelled · {date} · {name}: {note}", no actions.

### Editing mode
Steppers, remove X, + Add item, Take new toggles as in MS-123 (quantity blue when ≠ recorded; sub-line "Recorded N"). Pinned `procDetail.save` "Save changes" writes only the difference (`stock_procedure_edit`), Activity row "Edited usage · {name}", → done mode + toast "Usage updated". `procDetail.discard` text "Discard" → done mode, nothing changed. Reached directly from Home "Edit usage" (route param `mode=editing`).

### Cancel sheet (`cancelProcedure`)
Title "Cancel {name}?", warning Notice "N items will be returned to inventory. Stock levels update immediately.", required note "Why is it cancelled?" (placeholder "e.g. Logged by mistake, patient cancelled"), micro "Recorded in Activity with your name." Danger "Cancel procedure" disabled until the note has text; text "Keep" closes. Result: `stock_procedure_cancel` → Procedures + toast "{name} cancelled · N items returned".

### Acceptance criteria
- [ ] Edit +1 then −1 on different items writes exactly two transactions.
- [ ] Cancel returns countables to their original batches and reverses a bottle opened by this procedure if it is still open.

## MS-125 · Edit procedure templates
meta: milestone=M1; priority=P1; type=feature; area=procedures; size=3; frames=f15; screens=procEdit; prd=§6.3, Appendix B procEdit; depends=MS-122

### Screen (f15), Admin only
- Title "Edit procedure" (new: "New procedure"); header right `procEdit.save` primary small "Save" → Procedures + toast "Procedure saved".
- `procEdit.name` field labelled "Procedure name" ("Untitled procedure" if left empty).
- Eyebrow "DEFAULT SUPPLIES"; items list: `procEdit.item[productId].dec / .inc / .remove` default quantity (countables min 1; long names truncate with an ellipsis). Multi-use products show the caption "Multi-use · listed under Opened a new one?" instead of a stepper, with only a remove X; they appear on the start screen under "Opened a new one?" with default 0.
- `procEdit.addItem` round + → sheet addItem (all active products; multi-use labelled "· multi-use").
- `procEdit.delete` danger text "Delete procedure" at the bottom (existing only) → confirm sheet "Delete {name}?" · "Past procedures keep their data." Danger "Delete procedure" · "Keep". Archives the template.

### Acceptance criteria
- [ ] Matches f15 (both scroll positions).
- [ ] Editing defaults never changes past procedure events.
- [ ] Staff calling the RPC directly is rejected (MS-105).
