# app.dentory.ca

The files the invitation and password reset links need on `https://app.dentory.ca` (MS-100 D12, MS-112). Nothing here is served by the repository: host the folder as a static site at that domain (Cloudflare Pages, Netlify, a second GitHub Pages site; the marketing site at `dentory.ca` is a separate Pages site under `site/`).

| Path | What it does |
|---|---|
| `.well-known/apple-app-site-association` | Tells iOS that `https://app.dentory.ca/invite?token=…` opens the Dentory app. Replace `TEAMID` with the Apple Developer team id once the team exists (Apple Developer, Membership details). Serve it as `application/json` over HTTPS with no redirect; Apple's CDN fetches it when the app is installed. |
| `invite/index.html` | What a browser shows when the app is not installed or the link was opened on a computer: an "Open in Dentory" button (`dentory://invite?token=…`) and a note to install the app. |
| `reset-password/index.html` | The same for the password reset link (MS-113): `https://app.dentory.ca/reset-password?token_hash=…&type=recovery` becomes an "Open in Dentory" button (`dentory://reset-password?token_hash=…`). |
| `open/index.html` | The weekly digest's "Open Dentory" button (MS-145): `https://app.dentory.ca/open` opens the app where it was; in a browser, an "Open in Dentory" button (`dentory://open`) and a note to install the app. |
| `billing/done/index.html` | Where Stripe Checkout and the Customer Portal, opened from the billing email or Grigor's link, send the admin back (MS-140, MS-100 D18, `BILLING_RETURN_URL`): "Payment method saved", "Nothing was changed" or "Billing updated", and that the page can be closed; the app shows the change on its next return to the foreground. |

Until the domain is live, invitation links can be opened on the simulator with the app's own scheme: `xcrun simctl openurl booted "dentory://invite?token=…"` (see `make invite-links`). Password reset emails from the local stack already carry `dentory://reset-password?token_hash=…` (`supabase/README.md`).
