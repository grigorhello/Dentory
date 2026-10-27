# Performance

How to measure the figures of PRD §9 and MS-150 (#121): the Inventory list of a 500-product clinic scrolls at 60 fps on
an iPhone 12; Start procedure and Apply count complete in under 1 s at p95 on 4G; half the invoice readings finish in
under 20 s. The database part runs anywhere the local stack runs (a Mac or CI's Linux image); the device part needs the
Mac, an iPhone 12 and Instruments.

## The load-test clinic

`make db-reset seed-load` (or `make db-reset seed-demo seed-load`, both clinics) loads "Load test dental"
(`supabase/seed-load.sql`): 500 products in ten categories, 36% multi-use, 765 batches, about 5,500 ledger rows over six
months from 440 procedures, counts, receipts, adjustments, disposals and bottles, 20 procedure templates, To buy lines,
open alerts and two invoices waiting on Receive delivery. Its stock moved only through the stock functions, as the app
moves it. Sign in as olivia@loadtest.example (Admin) or hannah@loadtest.example (Staff), password `loadtest`.

Local stack only: never load it into a hosted project.

## Server time per call: `make perf-report`

Runs every call the app's screens make (the reads of Home, Inventory, Product detail and its history, Procedures,
Adjust then start, To buy, Expiring soon, Activity, Receive, Team and Inventory value) and the two writes the ticket
names, `stock_procedure_start` (the template with the most supplies) and `stock_count_apply` (50 corrections), as
PostgREST runs them for Olivia: role `authenticated`, her JWT claims, the answer built as JSON with the API's 1,000-row
cap. Each call runs 3 times to warm up, then 30 times (`make perf-report PERF_RUNS=100` for more), each run in its own
transaction; the writes are rolled back, so every run meets the same clinic. It analyses the tables first, as a hosted
project's autovacuum would have. It prints p50, p95 and the slowest run in milliseconds.

This is the database's time only. The phone's radio, the round trip, the API gateway and PostgREST come on top: on LTE
a round trip is about 50 to 100 ms, so a call that takes 20 ms here answers in roughly 100 to 200 ms on a phone.

What MS-150 measured (default branch before the change, then with `20261021150000_performance.sql`) is in the PR,
#121's acceptance record. Run the report again after any migration that touches a list, a policy or `product_stock`;
a call whose p95 grows past about 50 ms here is worth an `explain (analyze, buffers)` as Olivia:

```sql
begin;
select set_config('request.jwt.claims', '{"sub": "10ad0000-0000-4000-8000-000100000001", "role": "authenticated"}', true);
set local role authenticated;
explain (analyze, buffers) select * from public.inventory_list('10ad0000-0000-4000-8000-000000000001');
rollback;
```

## Several people at once: `make perf-concurrency`

Run it after `make perf-report` (it adds to the clinic). Eight clients (`PERF_CLIENTS`) make 20 stock changes each
(`PERF_TRANSACTIONS`) at the same time with `pgbench` inside the database container: three in four start a procedure
from a random template as a random member, every supply at its default and a new bottle of each multi-use supply; the
rest open a bottle of one of those products from its page. Every procedure uses the same four consumables, so the
changes meet on the same rows. `supabase/perf/concurrency-check.sql` then checks that every change was written (none
lost to a deadlock or an error), that each procedure has all its lines and bottles, that every bottle opened is an open
item, and that every product's batches and open bottles add up to its ledger. The run fails with the reason otherwise.

## On the Mac, with a device

Use a Debug build against the Mac's local stack with the load clinic: `make db-start`, `make db-reset seed-load`. A
phone cannot reach `127.0.0.1`, so for the iPhone create the git-ignored `Config/Secrets.debug.xcconfig` with the Mac's
address on the same Wi-Fi (`ipconfig getifaddr en0`) and the local anon key from `Config/Debug.xcconfig`:

```
SUPABASE_URL = http:/$()/192.168.1.20:54321
SUPABASE_ANON_KEY = <the SUPABASE_ANON_KEY line of Config/Debug.xcconfig>
```

`make project`, run on the iPhone 12 and sign in as olivia@loadtest.example. Delete the file afterwards, so Debug
builds go back to `127.0.0.1`. Record each result in the table at the end.

### 1. Inventory scrolls at 60 fps (iPhone 12)

1. Xcode, Product › Profile (a Release-like build), template Animation Hitches, target the iPhone 12.
2. Open Inventory and wait for the 500 rows. Record, then flick from the top to the bottom and back three times at a
   normal speed, type "glo" in the search and clear it, and tap All, Low, Healthy and All.
3. Then Count stock: tap + and − on ten rows, scroll to the bottom and back, Cancel and Discard.
4. Pass: hitch time ratio under 5 ms/s over the whole recording (Apple's "good"), and no single hitch longer than one
   frame (17 ms) while scrolling.

What to look at in the trace when it fails: `InventoryListViewModel.visibleProducts` and `ProductRow` in the Time
Profiler track (the list is sorted once per answer since MS-150, so typing or a stepper tap only filters it; a sort
showing up there again is a regression), and `FileCountDraftStore.save`, which writes the count draft on every stepper
tap on the main thread (a few hundred bytes; worth moving off the main thread if it shows above 2 ms).

### 2. Start procedure and Apply count under 1 s at p95 on 4G

1. On the iPhone: Settings › Developer › Network Link Conditioner, profile LTE, on. (Settings › Developer appears once
   the phone has been used with Xcode.)
2. Start procedure, 20 times: on Procedures tap Scaling and root planing (14 supplies), then Start procedure · 14 items
   on Adjust, then start. Time from the tap to the toast "Scaling and root planing started" on Procedures, from a
   screen recording (Control Centre's Screen Recording, read the frames in QuickTime) or a stopwatch app.
3. Apply count, 20 times: Count stock, change 10 rows, Review · 10 corrections, Apply count · 10 corrections. Time
   from the tap to the "Count applied" toast.
4. p95 of 20 runs is the 19th fastest. Pass: under 1 s for each.
5. Turn the Network Link Conditioner off.

Once the build carries a Sentry DSN (`docs/runbooks/monitoring.md`), Sentry measures the same call for every clinic:
Performance, transactions `stock_procedure_start` and `stock_count_apply` (operation `rpc`), column p95. That figure is
the round trip of the write from the phone, which is most of the tap-to-result time; the screen updates as it returns.

### 3. Invoice reading under 20 s at p50

1. `ANTHROPIC_API_KEY=… make invoice-reading-live` (a key in the shell, never in a file in the repo or a chat): reads
   the five fixture invoices with the real API and prints each time and the median.
2. On staging, once the pilot clinic has read real invoices, the median from the upload to the result, failed readings
   included and the demo clinic's seeded invoice left out (also `docs/handoff/build-state.md`, item 13):

```sql
select percentile_cont(0.5) within group (order by extract(epoch from read_at - created_at))
from invoices
where read_at is not null and status in ('ready', 'confirmed')
  and clinic_id <> 'd0000000-0000-4000-8000-000000000001';
```

Pass: under 20 s for both.

## Results

| Date | Build | Device, network | Inventory hitch ratio, longest hitch | Start procedure p95 | Apply count p95 | Reading p50 (live check, staging) | By |
|---|---|---|---|---|---|---|---|
| | | | | | | | |
