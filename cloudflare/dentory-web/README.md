# dentory-web (Cloudflare Worker)

One Worker on Grigor's Cloudflare account serves the public web for Dentory:

| Host | Serves | Notes |
|---|---|---|
| `https://dentory.ca` | `site/` | `/` is `index.html`, `/privacy` is `privacy.html`, `/support` is `support.html` (the App Store Connect URLs). `/privacy.html` redirects to `/privacy`. |
| `https://www.dentory.ca` | redirect | 301 to the same path on `https://dentory.ca`. |
| `https://app.dentory.ca` | `applinks/` | `/.well-known/apple-app-site-association` as `application/json` (universal links, team `886B9D4D6M`), `/invite`, `/reset-password`, `/open`, `/billing/done`. |
| `https://dentory-web.ggrigorgrigoryan.workers.dev` | preview | `site/`, and `applinks/` under `/_app/`. |

## How it works

`worker.js` fetches each file from this repository on GitHub (`raw.githubusercontent.com/grigorhello/dentory/<REF>/…`), caches it at Cloudflare's edge for `CACHE_SECONDS` (300), and answers with its own content type and headers. `REF` is `HEAD`, which GitHub resolves to the default branch, so **merging a change to `site/` or `applinks/` publishes it within about 5 minutes**. Nothing to build or upload. It only serves `.html`, images, CSS, JS, `.txt`, `.pdf` and the association file; never Markdown, dotfiles or anything outside those two folders.

## Changing the Worker itself

Only `worker.js` needs a redeploy. A thread does it with the Cloudflare connector (`PUT /accounts/{account_id}/workers/scripts/dentory-web`, multipart with `metadata` `{ "main_module": "worker.js", "compatibility_date": "2026-11-01", "bindings": [{ "type": "plain_text", "name": "REF", "text": "HEAD" }, { "type": "plain_text", "name": "CACHE_SECONDS", "text": "300" }] }` and the module). Grigor can instead run `npx wrangler deploy` in this folder after `npx wrangler login`; `wrangler.jsonc` holds the same settings. To preview a branch, deploy with `REF` set to the branch name and open the workers.dev URL, then set it back to `HEAD`.

The hostnames are Worker custom domains (`PUT /accounts/{account_id}/workers/domains`), which create the DNS records and certificates themselves. The zone's other records (Resend's `send`, `rsend`, `resend._domainkey`, and the Email Routing MX and TXT records) are independent of the Worker.

## Testing locally

`node` 22 can run the Worker against GitHub: import `worker.js`, call `worker.fetch(new Request("https://dentory.ca/privacy"), { REF: "<branch>" })` and check status, content type and body (set `NODE_USE_ENV_PROXY=1` behind a proxy).
