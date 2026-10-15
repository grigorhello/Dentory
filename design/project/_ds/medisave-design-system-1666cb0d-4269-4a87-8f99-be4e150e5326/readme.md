# MediSave Design System

Design system for **MediSave**, a dental inventory SaaS for independent dental clinics (1–10 dentists/hygienists, single location). Primary users are dental assistants, inventory coordinators and office managers; the buyer is the practice owner.

Product promise: *Know what your clinic has, what is running low, and what is expiring without continuously counting or scanning supplies.*

The visual language is adapted from a Zapier-inspired analysis file: warm cream canvas, deep coffee ink, one chromatic accent, 12 px radius. Per the brief, the coloring was shifted slightly: the orange accent becomes a **clinical blue** (`#1a63d6`) and an inventory-status palette (success / warning / danger) was added because the product lives on stock alerts.

## Sources

- `uploads/dental_inventory_saas_sellable_mvp_prd.pdf` — Sellable MVP PRD v1.0 (Oct 1 2026). Text extraction at `uploads/prd.txt`.
- `uploads/DESIGN.md` — "Zapier-Inspired-design-analysis" token file (colors, type ladder, radii, spacing, component chrome).
- No Figma, codebase, or logo was provided. **There is no logo**: the brand name is set in plain type wherever a mark would go.

## Products / surfaces

One product: a responsive web app (laptop, iPad, phone). Core screens from the PRD: Dashboard ("Needs Attention"), Inventory list, Product detail, Receive Delivery / Invoice Review, Procedure (prepare → complete / cancel), Reorder list, Quick count, Activity log, Settings & billing, Onboarding checklist.

## Content fundamentals

- **Voice**: practical clinic-operations tool, not an enterprise inventory system. Plain, direct, matter-of-fact. "Nothing affects inventory until reviewed."
- **Person**: speak to the clinic as *you / your clinic*; never "I". System messages are declarative: "34 Septocaine cartridges expire within 90 days. Estimated value at risk: $186."
- **Casing**: sentence case for headings, labels and buttons ("Confirm & receive", "Receive delivery", "Need to order"). Status words are short Title-case tokens: Healthy, Low, Out of stock, Expiring, Missing expiry, Needs count, Prepared, Completed, Cancelled.
- **Numbers first**: lead with the quantity and the consequence ("3 Low stock", "Current: 2 · Minimum: 3 · Target: 8 · Recommended reorder: 6").
- **Honest precision**: always label estimated vs exact ("System estimate: 43 · Actual: 41", "~50%", "Use lot A112 first – expires December 2026. Inventory assumption until confirmed.").
- **Verbs on buttons**: Receive, Prepare, Complete, Cancel, Adjust, Count, Add to order, Mark disposed, Undo.
- **No emoji.** No exclamation marks. No patient data anywhere in copy.
- Section eyebrows are UPPERCASE with 1 px tracking (the only uppercase in the system).

## Visual foundations

- **Color**: warm cream page `#fffefb`, soft cream cards `#f8f4f0`, coffee ink `#201515`. One accent, blue `#1a63d6`, reserved for primary actions, active nav, links and focus. Status colors are used as text + soft tinted pills, never as large fills. Neutrals are all warm; never cool grey, never pure black or pure white.
- **Type**: Outfit 500 (substituting Degular Display) for display sizes and eyebrows; Inter for everything else. Sentence-case headlines. Display sizes have tight line-height (1.0); body is 1.5.
- **Spacing**: 4 px base, tokens 2/4/8/12/16/24/32/48/64. Cards pad 24 px; page bands 64 px; table cells 12×16 px.
- **Radius**: 12 px for buttons, cards, dialogs; 6 px for inputs and inline chips; pill for status badges; full for avatars/icon circles. Buttons are never pills.
- **Elevation**: mostly flat. Level 1 is a 1 px ink hairline (outline buttons, inputs, featured cards); level 2 is surface contrast (cream card on canvas). Shadows only on floating layers: menus/toasts `--shadow-md`, dialogs `--shadow-lg`. No inner shadows.
- **Backgrounds**: solid cream or solid ink bands. No gradients, textures, photography or illustration in the product. Empty states are a cream frame with a caption.
- **Borders**: `--color-line #e6e1d6` for dividers and table rows; ink hairline for emphasis.
- **Hover**: primary darkens one step (`--color-primary-hover`); tertiary/ghost fill with canvas-soft; rows fill canvas-soft. **Press**: darkens a second step, no scale. **Focus**: 3 px soft-blue ring + 1 px blue.
- **Motion**: 120–180 ms, `cubic-bezier(.2,0,0,1)`, fades and color transitions only. No bounces, no slides larger than 8 px.
- **Transparency / blur**: none, except the dialog scrim `rgba(32,21,21,.4)`.
- **Layout**: app shell with a 240 px cream-soft sidebar, 64 px top bar, content max 1280 px. Mobile collapses the sidebar to a bottom tab bar.
- **Dark surfaces**: ink `#201515` with cream-soft text used for featured/flipped cards and the footer only.
- **Imagery**: none in V1. If ever used, product photos in 12 px frames.

## Iconography

- **Lucide** (CDN, `lucide` UMD) at 20 px, 1.75 px stroke, `currentColor`. Chosen because the source kit has no icon set and the PRD recommends shadcn-style tooling, which ships Lucide. See `components/core/Icon.jsx` (intentional addition).
- No icon font, no PNG icons, no emoji. Unicode arrows (→) appear only in audit-log deltas ("43 → 41").
- Status is always color + text label, never icon alone.

## Intentional additions (not in the source kit)

- `Icon` — Lucide wrapper so every component draws from one set.
- Status colors (success/warning/danger) — needed for stock, expiry and procedure availability states.
- `StatusBadge` variants on `Badge` — Healthy / Low / Out / Expiring / Needs count map directly to the PRD's inventory statuses.

## Index

- `styles.css` — entry; imports `tokens/*.css` (fonts, colors, typography, spacing, radius, elevation, base).
- `guidelines/` — foundation specimen cards (Colors, Type, Spacing, Shape, Brand).
- `components/actions/` — Button, IconButton
- `components/forms/` — Input, Select, Checkbox, Radio, Switch
- `components/display/` — Card, Badge, Tag, Tabs, Icon
- `components/feedback/` — Dialog, Toast, Tooltip
- `ui_kits/app/` — MediSave web app: Dashboard, Inventory, Product detail, Procedure, Invoice review (`index.html` is click-through).
- `thumbnail.html` — project tile.
- `SKILL.md` — agent skill entry point.
