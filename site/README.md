# Dentory landing site

Static site for the marketing plan: `index.html` (landing page with the trial sign-up form), `one-pager.html` (print to PDF, letter size, for clinic visits), `privacy.html` and `support.html` (the App Store listing links to them). Screenshots in `img/` are the design frames from `design/frames/` until captures from the shipped build replace them.

Placeholders to fill before going live: `VIDEO_LINK` (Loom demo), `FORM_ACTION` (Tally form URL, free, or `https://formsubmit.co/hello@dentory.ca`), `EMAIL`, `PHONE`, `DATE` in privacy.html, and `SIGNUP_LINK` in the one-pager.

Hosting: GitHub Pages from the `site/` folder through `.github/workflows/pages.yml`. Enable it once in the repo settings (Settings, Pages, Source: GitHub Actions), then every push to the default branch publishes. Point the domain at it with a CNAME (Settings, Pages, Custom domain), or move the folder to Cloudflare Pages later; nothing in it depends on the host.
