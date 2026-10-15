# MediSave design (V1.1)

Everything a developer needs to build the V1.1 iPhone and iPad app. Exported from the Claude Design project "Mobile app design for MediSave" on October 15, 2026. Treat this folder as read-only input.

| What | Where |
|---|---|
| Product requirements, readable | `PRD-v1.1.md` (sections 1–10, screen index, Appendix B element ids, Appendix C sheets) |
| Every screen as an image | `frames/fNN.png` (f01–f38, numbers match the PRD). `fNN-2.png`, `-3.png`… are the same screen scrolled further down. |
| Clickable prototype source | `project/MediSave Mobile.dc.html` (one file, all screens and sheets; seed data in the `constructor` of the script at the bottom) |
| Design board source | `project/MediSave Board.dc.html` |
| PRD source | `project/MediSave PRD v1.1.dc.html` |
| Design system | `project/_ds/medisave-design-system-1666cb0d-4269-4a87-8f99-be4e150e5326/` (`readme.md`, `tokens/*.css`, `_ds_bundle.js` React components) |
| Designer notes | `project/DESIGN-NOTES.md` |

## Frame index

| Frame | Screen | Prototype `screen` |
|---|---|---|
| f01 | Sign in | signin |
| f02–f04 | Admin sign-up: account, clinic, invite team | onboard (step 0–2) |
| f05 | Accept invitation (Staff) | invite |
| f06 / f07 | Home Admin / Staff | home |
| f08 / f09 | Activity alerts / history | activity |
| f10 | Inventory value | value |
| f11 / f12 | Procedures Admin / Staff | proc |
| f13 | Adjust, then start | procDetail (new) |
| f14 | From history, edit usage | procDetail (done) |
| f15 | Edit defaults | procEdit |
| f16 / f17 | Inventory Admin / Staff | inv |
| f18 | Count stock | inv (count) |
| f19 | Low filter | inv (filter Low) |
| f20 / f21 | Product detail Admin / Staff | product |
| f22 | Receive delivery | receive |
| f23 | Review invoice | invoice |
| f24 | Receive manually | manual |
| f25 / f26 | To buy Admin / Staff | order |
| f27 / f28 | Expiring soon Admin / Staff | expiring |
| f29 / f30 | Account Admin / Staff | more |
| f31 / f32 | Team Admin / Staff | team |
| f33 | Clinic settings | settings |
| f34 | Billing | billing |
| f35 | Invoices | invoices |
| f36–f38 | iPad: Home, Procedure, Review invoice | home, procDetail, invoice |

Sheets (bottom sheets) are not drawn as frames; they are specified in `PRD-v1.1.md` Appendix C and implemented in the prototype under `<!-- SHEETS -->`.

## Re-rendering the frames

`render-frames.js` renders the board with Playwright and saves one PNG per frame. It needs the four CDN scripts the prototype loads (react, react-dom, lucide, @babel/standalone) available locally; see the script header.
