# Starting catalogs

A starting catalog is a list of products a clinic can begin with instead of an empty Inventory: the products a practice of its kind keeps in stock, each with its category, its units, a starting minimum and target, and how it is tracked. It goes into one clinic, local or hosted, with `make seed-catalog`. The clinic then sets its real quantities, archives what it does not carry, renames products to its brands and adds the rest in the app.

| File | What it is |
|---|---|
| `general-practice.sql` | A small Canadian general practice: two or three operatories, a dentist or two, hygienists. 74 products over the ten default categories. |
| `seed.sh` | `make seed-catalog`: puts the clinic's id into a catalog and sends it to the database. |
| `check.sh`, `check.sql` | `make catalog-check`: the catalog on two new clinics on the local stack (CI runs it). |

## What a catalog writes

Only categories and products, as an admin would type them on New product (MS-117): name, category, counted-in unit, received-as pack and pack size, minimum, target, tracking. Supplier, location and cost stay empty: they are the clinic's to fill, and receiving sets the cost. It writes no batches, ledger rows, open bottles or To buy lines, so every product starts at 0.

It is re-runnable. It adds only the categories and products the clinic does not have yet, matching names without regard to case and counting archived products, so nothing the clinic deleted comes back; it changes nothing that exists. A missing category is added after the clinic's last one, as New category does. It refuses a clinic id no clinic has, and it is one SQL statement, so if any part fails nothing is added.

Names are matched as written, only without regard to case: a clinic's own name for the same product ("Patient bib" for the catalog's "Patient bibs") does not stop the catalog's, so a catalog suits a clinic with few products of its own. The demo clinic, which shares 17 names with the general practice, gets the other 57. For the same reason, run it once per clinic, before the clinic renames products: a product renamed in the app no longer matches its catalog name, so a second run would add the catalog's name again.

### The general practice

| Category | Products | Multi-use |
|---|---|---|
| Anesthetic | 6 | 1 |
| Restorative | 14 | 9 |
| Endodontics | 8 | 2 |
| Impression | 7 | 5 |
| Preventive | 6 | 2 |
| Surgical | 6 | 2 |
| PPE | 6 | 0 |
| Sterilization | 9 | 5 |
| Disposable | 9 | 0 |
| Other | 3 | 1 |
| **Total** | **74** | **27** |

- **Names**: the generic product and the variant a clinic orders (shade, size, gauge, strength), in sentence case as on the box; a brand only where it is the everyday name, as the demo seed does ("Septocaine 4% 1:100,000"). No SKUs or prices.
- **Counted in**: single items where a procedure uses a set number of them, so a procedure template can take them (cartridges, needles, capsules, doses, sutures, blades, prophy angles and cups, matrix bands); bulk disposables in the box, bag, pack, sleeve or case they are stored in, since nobody counts bibs one by one.
- **Packs** only where nearly every brand sells the same one: cartridges 50 to a box, needles 100, glass ionomer capsules 50, prophy cups 200, prophy angles 100, scalpel blades 100, collagen plugs 10, gloves 10 boxes to a case, disinfectant wipes 12 canisters to a case. Elsewhere the clinic adds its own when it knows its brand: a wrong pack size would turn every received box into the wrong quantity.
- **Minimum and target**: the minimum is about a week of use and the target two to three weeks, for a practice of that size; edit them after a few weeks of counts. To buy suggests target less stock when a product falls to its minimum.
- **Multi-use** (MS-100 G1): what is opened and used across patients, counted in containers (bottles, syringes, jars, kits, impression cartridges, canisters, cans, bags of alginate). Its minimum counts unopened spares only (G3): 0 for a slow mover means Low as soon as no spare is left, with a target of 2 (one open, one spare).

## Running it on a clinic

```sh
make seed-catalog CLINIC_ID=<uuid> [CATALOG=general-practice] [TARGET=local|linked]
```

- Push the migrations to that project first (`supabase db push`): without `20261107063703_no_alerts_before_first_stock.sql`, the nightly refresh opens an Out of stock alert, a push and a To buy line for every product still at 0.
- `CLINIC_ID` is the clinic's `id` in `public.clinics`. On a hosted project: `supabase db query --linked "select id, name from public.clinics order by created_at"`.
- `TARGET=local` (the default) writes to the local stack. `TARGET=linked` writes to the project this clone is linked to (`supabase link --project-ref <ref>`; production's ref is the Makefile's `PRODUCTION_REF`), through the Management API with the CLI's own login (`supabase login`): no database password or key is read, passed or printed. `TARGET` is read from the command line only, never from the environment.
- It prints the target first, then what it added: `Smile Groove: added 0 categories and 74 products from the general-practice catalog.` A run that changes nothing says 0 and 0.
- `supabase db query --local` refuses several statements at once (`cannot insert multiple commands into a prepared statement`), and psql variables reach neither target, so a catalog is a single statement, which runs the same way on the local stack and through the Management API, with `__CLINIC_ID__` where the id goes; `seed.sh` puts the id there after checking it. It passes `--yes`, since newer CLIs ask before a statement goes to a hosted project and a run without a terminal could not answer.

## What the clinic sees afterwards

Checked by `make catalog-check` against the database as it is.

1. **Right away, and until each product's first stock**: Inventory lists every catalog product at 0 with the badge Out of stock (a product's status is worked out as it is read), its page says the same, and the Low filter shows them all, since Low includes Out of stock. Nothing else changes: no alert in Activity, no push, no To buy line, no Home tile, no stock value. A product never stocked raises nothing (`supabase/migrations/20261107063703_no_alerts_before_first_stock.sql`): not at the nightly status refresh (pg_cron, 07:00 UTC), not when its minimum or target changes, not when a procedure uses it (stock never goes below 0, so the procedure takes nothing), and not when a count finds none. Add to buy still puts it on To buy by hand.
2. **When the clinic sets a product's quantity**, the product is stocked from then on and behaves like any other:
   - Receive manually (Admin) takes the quantity in the pack (boxes, cases), the expiry month and the lot: the product is Healthy, or Expiring for a close date.
   - Adjust (on the product, both roles; Actual quantity, reason Physical count) or Count stock set the quantity without an expiry date (MS-100 D9), so the product reads Missing expiry, with its alert, until its dates are entered on the product.
   - If the quantity is at or under the minimum, the product reads Low: its Low alert opens and To buy suggests target less stock. When a product once stocked is used down to 0, it goes Out of stock with its alert, its push at 7 AM clinic time (MS-144's waking hours) and its To buy line, as before.
   - Count stock's steppers move one at a time: quick for products counted in boxes, bags and bottles, slow for one counted by the hundred. For those, type the quantity in Adjust or receive it.
   - A multi-use product counts unopened containers only: count the one in use too, then Open a new bottle on its page, so it reads, say, 2 unopened and 1 open.
3. **Products the clinic does not carry**: Delete product on the product's page (Admin) archives it and takes it out of Inventory; a later catalog run does not bring it back.

So a catalog can go into a clinic whenever it suits: the clinic enters its stock product by product, over days if it needs to, and each product starts to raise alerts and To buy suggestions from its first quantity.

## Adapting a copy for another kind of practice

1. Copy `general-practice.sql` to `<kind>.sql` (lower case and hyphens, the name `CATALOG=` takes), for example `orthodontics.sql`, and change its first comment.
2. Edit only the `values` list: one product per line, `(position, category, name, unit, pack_unit, pack_size, minimum, target, tracking)`, positions 1, 2, 3 in the order the products should join the clinic. Use the default category names (MS-100 D13) where they fit; a category a new clinic lacks (`Orthodontics`) is added after its last one. Follow the conventions above: units plural and lower case (`cartridges`), packs singular (`box`) with a size of 2 or more or both `null`, the target at least the minimum, `countable` or `multi_use`. Product names must differ from one another, and a quote inside a name is written twice (`'Children''s toothbrushes'`).
3. Leave the statement below the list as it is, and keep it one statement with `__CLINIC_ID__` where it is.
4. `make db-reset catalog-check CATALOG=<kind>` checks it on the local stack. CI checks `general-practice` only, unless the database job runs the new one too.
