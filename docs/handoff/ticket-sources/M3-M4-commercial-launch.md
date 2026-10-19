# M3 · Commercial beta: account, team, billing, notifications

## MS-137 · Account screen and sign out
meta: milestone=M3; priority=P0; type=feature; area=settings; size=2; frames=f29,f30; screens=more; prd=§6.9 Account; depends=MS-114

### Screen (f29 Admin, f30 Staff), from Home `home.header.account`
- Pushed title "Account".
- `more.user` card: initials avatar (ink circle), full name, "{Role} · {Clinic}".
- Group 1: `more.team` "Team" with "N people" right → Team (MS-138); Admin only: `more.settings` "Clinic settings" → MS-139, `more.billing` "Billing" → MS-140, `more.export` "Export CSV" → MS-143. Icons: Users, Settings, CreditCard, Download.
- Group 2: `more.help` "Help" (LifeBuoy) → opens the help centre URL in the in-app browser (placeholder `https://{domain}/help` until Grigor provides one; D12); `more.signOut` "Sign out" (LogOut, danger text and chevron) → confirm sheet "Sign out?" · "You can sign in again with your email." Danger "Sign out" · "Keep" → clears session, cached data and push token → Sign in.
- Staff (f30): Team, Help, Sign out only.

### Acceptance criteria
- [ ] Matches f29 and f30. Sign out removes cached clinic data from the device.

## MS-138 · Team: invite, resend, change role, remove
meta: milestone=M3; priority=P0; type=feature; area=team; size=3; frames=f31,f32; screens=team; prd=§6.9 Team, Appendix C invite; depends=MS-112,MS-137

### Screen (f31 Admin, f32 Staff)
- Pushed title "Team"; Admin header primary small `team.invite` "Invite" (UserPlus) → sheet `invite`.
- `team.member[userId]` rows: initials avatar (pending: "—"), name and email (pending: email as title and "Invited · {date}"), role right ("Admin" in primary blue, "Staff" secondary). Order: admins, staff, then pending.
- Admin: tap a row → `team.member[userId].menu` action sheet: "Change role" (to Admin / to Staff), "Resend invitation" (pending only; toast "Invitation sent"), "Remove from clinic" / "Revoke invitation" (confirm sheet "Remove {name}?" · "They lose access right away. Their history stays." Danger "Remove" · "Keep"). The last Admin cannot be demoted or removed: show the toast "A clinic needs at least one admin."
- Staff: read-only list, no menu, no Invite (f32).

### Invite sheet
Title "Invite a teammate". Name (optional), Email, Role (Staff, Admin; segmented, Staff default), primary "Send invitation" → MS-112 function → pending row + toast "Invitation sent · They get a link by email." Duplicate email error inline: "{email} is already on the team."

### Acceptance criteria
- [ ] Matches f31/f32 with the demo seed.
- [ ] A removed user is signed out on next request and cannot read clinic data.

## MS-139 · Clinic settings
meta: milestone=M3; priority=P1; type=feature; area=settings; size=2; frames=f33; screens=settings; prd=§6.9 Clinic settings, §8; depends=MS-137

### Screen (f33), Admin only
- Pushed title "Clinic settings", header text `settings.save` "Save" (enabled when something changed) → toast "Settings saved".
- `settings.logo` logo (tap to replace; same picker as onboarding). `settings.clinicName` Clinic name. `settings.city` City, `settings.country` Country (PRD). Currency and Time zone selects as drawn in f33, prefilled from country and device, editable (decision D14).
- Eyebrow "ALERTS": `settings.expiryWarning` select "30, 60 and 90 days" · "60 and 90 days" · "90 days only" (D8). `settings.digest` card "Email digest · Weekly, Monday 7 am" with a Switch.
- Leaving with unsaved changes asks "Discard changes?" · Danger "Discard" · "Keep editing".

### Acceptance criteria
- [ ] Changing the expiry warning recomputes Expiring statuses and Home counts.

## MS-140 · Billing: trial, price and payment method with Stripe
meta: milestone=M3; priority=P0; type=feature; area=billing; size=5; frames=f34; screens=billing; prd=§6.9 Billing, §9 Billing, §1 Billing; depends=MS-137,MS-104

### Commercial rules
3-month free trial from clinic creation, then $99 per clinic per month (USD price list; show the clinic currency only when a matching Stripe price exists, otherwise USD), unlimited users. Some clinics get a 50% lifetime promotion ($49.50): a flag set by Dentory (`promo_lifetime_50`, via SQL or Stripe coupon), never editable in the app.

### Screen (f34), Admin only
- `billing.trial` dark ink card: eyebrow "FREE TRIAL", "3 months free" (or "{N} days left" in the last 30 days), "Ends {date}". Divider, "After trial" and `billing.price` "$99 / month" or "~~$99~~ $49.50 / month" with success pill "50% off for life". After the trial with an active subscription: eyebrow "PLAN", "$99 / month", "Next payment {date}".
- `billing.paymentMethod` row "Payment method" with "Visa ·· 4242" and text "Change" (or "Add" when none) → opens a Stripe-hosted page in the in-app browser: Stripe Checkout in subscription mode with `trial_end` = clinic trial end when no subscription yet; Stripe Customer Portal when one exists (D11).
- `billing.invoices` row "Invoices" with "None yet" / count → MS-141. `billing.emails` row "Billing emails" with the first address → MS-141 sheet.

### Server
- Edge Functions `billing_checkout`, `billing_portal` (admin only) return URLs; `stripe_webhook` (signature verified) updates `subscription_status`, card brand/last4, and stores invoices (id, date, amount, status, hosted PDF URL).
- Stripe customer created at clinic creation with the admin email; billing emails synced to Stripe.

### Acceptance criteria
- [ ] Matches f34 for trial, promo and no-card states (Stripe test mode).
- [ ] Adding a test card in Checkout updates the row after the webhook, without restarting the app.

## MS-141 · Billing invoices and billing emails
meta: milestone=M3; priority=P2; type=feature; area=billing; size=2; frames=f35,f34; screens=invoices,billing; prd=§6.9, Appendix C billingEmails; depends=MS-140

### Invoices screen (f35)
Pushed title "Invoices". `invoices.row[id]`: date, amount, status badge (Paid success, Open warning, Failed danger), "PDF" opens the Stripe hosted invoice in the in-app browser. `invoices.empty` EmptyState "No invoices yet".

### Billing emails sheet (`billingEmails`)
Title "Billing emails", caption "Invoices and receipts go to every address here." List: the admin's email first (not removable), others with an X. Email field + "Add" (validates format, no duplicates). Primary "Done" saves → toast "Billing emails updated".

### Acceptance criteria
- [ ] Matches f35. Emails sync to the Stripe customer.

## MS-142 · Read-only mode when the trial ends without payment
meta: milestone=M3; priority=P0; type=feature; area=billing; size=3; frames=f6,f34; screens=home,billing; prd=§9 Billing, G5; depends=MS-140,MS-105

Not drawn (gap G5). Build from existing components.
- When `trial_ends_at` has passed and there is no active subscription (or status canceled/past_due beyond Stripe's retry window), `clinic_can_write` returns false: every write RPC fails with error code `read_only`.
- Home: Notice warning above the tiles: Admin "Your free trial has ended. Add a payment method to keep updating stock." with a text button "Billing"; Staff "Your clinic's trial has ended. Ask your admin to add a payment method."
- Billing card shows "Trial ended" instead of days left.
- Any write action (Start procedure, Adjust, Count, Receive, Add to buy…) opens a sheet "Your clinic is in read-only mode" · "You can still see everything. Add a payment method to make changes." Admin primary "Go to Billing"; Staff only "OK".
- Reading stays fully available. 7 days before the trial ends, Admins see the Home notice "Your free trial ends on {date}." with "Add payment method".

### Acceptance criteria
- [ ] With `trial_ends_at` in the past, every write path shows the sheet and the database rejects the RPC.
- [ ] Adding a card restores writes after the webhook.

## MS-143 · Export CSV
meta: milestone=M3; priority=P2; type=feature; area=reports; size=2; frames=f29; screens=more; prd=§6.9 Export CSV; depends=MS-137

- `more.export` (Admin) starts an export job → toast "Export started · We'll email it to {admin email}."
- Edge Function builds a zip with `products.csv` (name, category, unit, pack unit, pack size, tracking, minimum, target, supplier, location, quantity, unopened, open, last unit cost, status, archived), `batches.csv` (product, expiry month, lot, qty), `transactions.csv` (date, type, product, delta, before, after, user, reference, reason, note), UTF-8 with BOM for Excel, dates ISO 8601, and emails a signed download link valid 7 days.
- Rate limit: one export per clinic per 10 minutes.

### Acceptance criteria
- [ ] The zip opens in Excel and Numbers with correct accents and numbers.

## MS-144 · Push notifications
meta: milestone=M3; priority=P1; type=feature; area=alerts; size=3; frames=; screens=; prd=§8 Notifications; depends=MS-133

- Ask permission at first launch after sign-in (iOS prompt, preceded by a one-line explainer sheet "Get alerts for out-of-stock items, expiring stock and invoices ready to review." with "Turn on" / "Not now").
- Register the APNs device token (`UIApplicationDelegateAdaptor`, `registerForRemoteNotifications`) in `push_tokens`; remove on sign out. Edge Function `send_push` sends through APNs with a token-based auth key (`.p8` in Supabase secrets); no third-party push service.
- Send (server, from alert creation): Out of stock (all members), Expiring within 30 days (all members, once per batch), Invoice read and ready to review (Admins only). Tap opens the same deep link as the alert row.
- Quiet bundling: at most one push per product per day.

### Acceptance criteria
- [ ] On a device build, each of the three events delivers one push that deep-links correctly.

## MS-145 · Weekly email digest
meta: milestone=M3; priority=P2; type=feature; area=alerts; size=2; frames=f33; screens=; prd=§8 Email digest; depends=MS-139

- When `email_digest` is on, every Monday 07:00 clinic time send to every Admin: To buy count, items expiring within the window (top 5 with days), missing expiry count, procedures last week (count). Subject "This week at {Clinic}: {N} to buy, {M} expiring". Plain, on-brand HTML (cream background, ink text, one blue button "Open Dentory").
- pg_cron hourly job selects clinics whose local time is Monday 07:00.

### Acceptance criteria
- [ ] Digest renders in Gmail and Apple Mail; turning the switch off stops the next send.

## MS-146 · Let admins delete invoice files
meta: milestone=M3; priority=P2; type=feature; area=receiving; size=1; frames=; screens=; prd=§9 Privacy; depends=MS-131

Invoice images belong to the clinic and can be deleted by an admin. On a confirmed invoice opened read-only (from Activity), Admin header menu "Delete invoice file" → confirm sheet "Delete the invoice file?" · "Received stock and history stay. Only the image or PDF is removed." Danger "Delete file" · "Keep". Removes the Storage objects and sets `storage_path` null.

### Acceptance criteria
- [ ] File is gone from Storage; the invoice lines and transactions remain.

## MS-147 · Track product analytics with the element ids
meta: milestone=M3; priority=P2; type=tech; area=platform; size=2; frames=; screens=; prd=Appendix B (element ids are analytics event names); depends=MS-103

- PostHog (EU or US cloud, no session replay, no autocapture of text inputs). Events named by the Appendix B element ids, e.g. `procDetail.start`, `invoice.confirm`, `inv.count.review`, with properties: role, item count, duration where relevant. Never send product names typed by users, notes, emails or invoice contents.
- Pilot metrics dashboard: weekly active clinics, procedures started per clinic per week, invoices confirmed, share of invoice lines auto-matched, counts applied, time from invoice upload to confirm.

### Acceptance criteria
- [ ] Events appear for one full procedure and one invoice flow; a test asserts no event payload contains free text.

# M4 · V1.1 launch

## MS-148 · iPad layout pass
meta: milestone=M4; priority=P1; type=feature; area=platform; size=2; frames=f36,f37,f38; screens=home,procDetail,invoice; prd=§6.10; depends=MS-136

Same screens and the same bottom tabs on iPad. Content capped at 720 px and centred; sheets centred at the same width; both orientations; no sidebar or split view in V1.1. Walk every screen on iPad Pro 11" and 13" simulators in both orientations and fix layout issues (wide gutters, pinned bars spanning only the 720 column, keyboard avoidance in sheets).

### Acceptance criteria
- [ ] Home, Procedure and Review invoice match f36, f37, f38; every other screen has no clipped or stretched element.

## MS-149 · Accessibility and Dynamic Type pass
meta: milestone=M4; priority=P1; type=chore; area=platform; size=3; frames=; screens=; prd=§7 Accessibility; depends=MS-136

- Hit targets ≥ 44 px; text ≥ 12 px; contrast ≥ 4.5:1 (check status colors on soft tints); status always text + color.
- Dynamic Type up to the Large step without truncation on every screen (numbers in steppers and tiles may wrap the label, never the number).
- VoiceOver: every control has a label (use the element id text, e.g. "Increase Septocaine, 2"), steppers expose adjustable actions, toasts are announced, sheets trap focus and close with the escape gesture.
- Reduce Motion: fades only (already the default).

### Acceptance criteria
- [ ] An audit checklist per screen in the PR description, all items passing.

## MS-150 · Performance, backups and reliability
meta: milestone=M4; priority=P1; type=tech; area=platform; size=3; frames=; screens=; prd=§9 Performance, Concurrency; depends=MS-136

- Load test with a 500-product, 5,000-transaction clinic: Inventory list scroll at 60 fps on iPhone 12; Start procedure and Apply count complete in < 1 s p95 on 4G; invoice reading < 20 s p50.
- Index review (EXPLAIN on the main queries), N+1 checks in the data layer.
- Supabase Pro: daily backups + point-in-time recovery enabled; a written restore drill done once into a staging project.
- Monitoring: Sentry alerts for crash-free sessions < 99.5% and RPC error rate; Edge Function timeouts alert.

### Acceptance criteria
- [ ] Numbers above recorded in the PR; restore drill documented in `docs/runbooks/restore.md`.

## MS-151 · Security review before launch
meta: milestone=M4; priority=P0; type=chore; area=platform; size=2; frames=; screens=; prd=§9 Privacy, Audit; depends=MS-136

- Run the `security-review` skill on the repository; fix every high finding.
- Verify: RLS on every table (automated test listing tables without RLS fails CI), no service-role key in the app bundle, Storage policies, Stripe webhook signature check, invitation token hashing and expiry, rate limits on invite, export and password reset, no patient or appointment fields anywhere, no PII in logs or analytics.

### Acceptance criteria
- [ ] Security review report committed under `docs/security/` with all highs resolved.

## MS-152 · Ship to TestFlight and the App Store
meta: milestone=M4; priority=P0; type=chore; area=platform; size=3; frames=; screens=; prd=§9 Platforms; depends=MS-148,MS-149,MS-150,MS-151

- Xcode Cloud workflows (pull request: build + test; `main`: archive and upload to TestFlight; tag `v*`: App Store build), or the same with `xcodebuild archive` + `xcrun altool` in GitHub Actions if Xcode Cloud is unavailable; App Store Connect app record; bundle id, the App Store icon `design/brand/ios/dentory-app-store-1024.png` (the app icon itself ships with MS-158), the launch screen from MS-160.
- Privacy nutrition labels (email, name, usage data; no health data; no tracking), privacy policy and terms URLs, support URL.
- Review notes: demo account (Smile Dental admin) for App Review.
- Billing review risk (D11): confirm before submission that linking to Stripe-hosted billing for a B2B per-clinic subscription is accepted; if not, hide the payment method row on iOS and bill by email invoice for pilot clinics.
- Release checklist in `docs/runbooks/release.md`.

### Acceptance criteria
- [ ] Production build available on TestFlight for external testers; App Store submission sent.
