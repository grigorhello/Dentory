# Dentory landing site

Static site for the marketing plan: `index.html` (landing page with the trial sign-up form), `one-pager.html` (print to PDF, letter size, for clinic visits), `privacy.html` and `support.html` (the App Store listing links to them). Screenshots in `img/` are the design frames from `design/frames/` until captures from the shipped build replace them.

The contact address on every page is `hello@dentory.ca` (Cloudflare Email Routing forwards it to Grigor). There is no sign-up form and no phone number: the trial button opens an email. To add a form later (Tally, free) or a phone number, change `index.html` and `one-pager.html`.

Hosting: the Cloudflare Worker in `cloudflare/dentory-web/` serves this folder at `https://dentory.ca` straight from the default branch, so a merged change is live within about 5 minutes. Pages are reached without `.html` (`/privacy`, `/support`), so link them that way.
