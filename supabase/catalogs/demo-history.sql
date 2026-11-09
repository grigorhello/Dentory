-- Demo history: about six weeks of a small general practice's stock, ending today, for a clinic that holds the
-- general-practice starting catalog (general-practice.sql) and has never stocked it. Operations work, no ticket:
-- Grigor's ask of 2026-11-09 for the pilot clinic Smile Groove on production, "Make a realistic history. Make the data
-- in a state so that its ready for demo". README.md beside this file says when to run it and what it leaves.
--
-- Run it with `make seed-demo-history CLINIC_ID=<uuid> [TARGET=local|linked]` (demo-history.sh), which puts the
-- clinic's id where __CLINIC_ID__ stands and sends the file with `supabase db query`. It is one statement, so it runs
-- the same on the local stack and through the Management API, as one transaction: if any part fails, or the end state
-- is not the one below, nothing is written. The ledger is append-only, so what it writes stays in the clinic for good:
-- run it on demo clinics only. With __DRY_RUN__ true it stops after its checks, with an error that says what it would
-- write (`supabase db query` shows no notices, and an error writes nothing); demo-history.sh runs it that way first
-- and prints that.
--
-- The method is seed-demo.sql's. Stock moves only through the MS-106 engine functions and the app's own To buy,
-- template and archive functions, called as the clinic's admin, so batches, open bottles, the ledger, alerts and To buy
-- lines are what the engine writes; after each step the rows it wrote move back to the step's moment in the story,
-- timestamps only, never a quantity, with the ledger's append-only trigger off for that and back on before the end.
-- Days are relative to today in the clinic's time zone; today's steps run only up to now, so nothing is dated in the
-- future. Every choice the story makes is a hash of its step (pg_temp.demo_rand), never random().
--
-- The story. The practice opens Monday to Friday, 8 to 5. On the Monday six weeks back (S) the admin enters the opening
-- stock as three deliveries, one per supplier (lots, expiry months, unit costs in CAD), and creates eight procedure
-- templates. Every working day then brings about 13 procedures from those templates (recall cleanings, fillings,
-- extractions, root canals, crown preps and seats, emergencies), some adjusted before they start, and on about every
-- other day one edited after it started; the multi-use syringes, bottles and kits are taken new as the open ones run
-- out and marked finished. Mondays and Thursdays at 4:30 pm the admin orders what To buy holds and what will run short before the
-- next delivery, by To buy (lines the engine added, or Add item, set to whole packs, then Mark as ordered); each
-- supplier delivers two working days later. Fridays at 4 pm a count corrects the bulk disposables (counted by the box)
-- and a few small shortfalls. Along the way: a dropped box of cartridges, a procedure logged by mistake and
-- cancelled, a box found at a count and its expiry added two days later, a lot of plain anesthetic that expired and is
-- disposed of, and a box of rubber dam sheets lost to water at the very end.
--
-- The end state, the day it runs (checked at the end; any difference rolls everything back):
-- - Low and on To buy: Earloop masks level 3 and Matrix band, marked Ordered at the end of the last working day;
--   Composite A2 and Fluoride varnish 5%, still to buy.
-- - Out of stock and on To buy: Rubber dam latex-free, whose open box got wet at the end of the last working day, after
--   that day's order went out.
-- - Expiring soon (within 90 days): Collagen plugs (a lot from the opening stock, within about 30 days), and a box of
--   Glass ionomer restorative and one of Lidocaine 2% 1:100,000 from the last delivery, short-dated.
-- - Missing expiry: Paper points, whose last box was received without its expiry.
-- - Every other catalog product Healthy, the multi-use ones in use with a bottle open.
-- - "Pen" and "Pain killer", the clinic's own test products, archived through Delete product (product_archive), with
--   whatever stock they hold, as the app archives a product.
-- - No push or email goes out for the history: its pushes are marked never to be sent, as push_claim marks a push
--   whose alert closed, whose product was archived or that waited over a day; no digest is queued.
do $$
declare
  c constant uuid := '__CLINIC_ID__';
  v_dry_run constant boolean := __DRY_RUN__;
  -- The story's now: its last step is before it. The rows each step writes carry now(), the transaction's time.
  v_now constant timestamptz := now();
  v_clinic public.clinics;
  v_admin uuid;
  v_tz text;
  v_today date;
  v_start date;
  v_last date;
  v_wrong text;
  v_count integer;
  v_round_last integer;
  v_final_count timestamptz;
  ev record;
  pr record;
  v_id uuid;
  v_items jsonb;
  v_lines jsonb;
  v_ids uuid[];
  v_qty numeric;
  v_unopened numeric;
  v_measure numeric;
  v_need_now numeric;
  v_need_next numeric;
  v_need numeric;
  v_deliver timestamptz;
  v_next timestamptz;
begin
  -- The clinic and its admin, or the refusal before anything is written ---------------------------------------------

  select * into v_clinic from public.clinics where id = c;
  if v_clinic.id is null then
    raise exception 'No clinic has the id %: nothing was written.', c using errcode = 'P0002';
  end if;
  v_tz := v_clinic.time_zone;
  select m.user_id into v_admin
  from public.memberships m
  where m.clinic_id = c and m.role = 'admin' and m.status = 'active'
  order by m.invited_at, m.created_at
  limit 1;
  if v_admin is null then
    raise exception '% has no active admin to write the history as: nothing was written.', v_clinic.name
      using errcode = 'P0001';
  end if;
  if not public.clinic_can_write(c) then
    raise exception '% is read-only (no trial left and no payment method): nothing was written.', v_clinic.name
      using errcode = 'P0001';
  end if;

  v_today := (v_now at time zone v_tz)::date;
  v_start := date_trunc('week', v_today - 42)::date;
  select max(d)::date into v_last
  from generate_series(v_start, v_today - 1, interval '1 day') d
  where extract(isodow from d) < 6;

  -- A fixed number in [0, 1) for a named choice of the story.
  create function pg_temp.demo_rand(p_key text) returns numeric language sql immutable as $f$
    select ('x' || substr(md5('demo-history:' || p_key), 1, 8))::bit(32)::bigint / 4294967296.0
  $f$;

  -- The catalog's products as the story uses them: supplier, unit cost (CAD), how they are used up (used: a set number
  -- per procedure; bulk: counted by the box at the Friday counts, k a day; open: a multi-use product used from its open
  -- one, k uses to a container; facility: a multi-use product opened every k working days; idle: not used in the
  -- story), shelf life of a delivered lot in months, and the part a product plays in the end state.
  create temp table demo_product on commit drop as
  select s.n, s.name, s.unit, s.tracking, s.supplier, s.cost, s.kind, s.k, s.shelf, s.role,
         p.id, p.unit as clinic_unit, p.tracking::text as clinic_tracking, p.pack_size, p.minimum, p.target,
         null::numeric as desired, null::timestamptz as horizon, null::integer as landing
  from (values
    (1, 'Septocaine 4% 1:100,000', 'cartridges', 'countable', 'Henry Schein', 1.42, 'used', null, 24, 'D1'),
    (2, 'Lidocaine 2% 1:100,000', 'cartridges', 'countable', 'Henry Schein', 0.92, 'used', null, 24, 'E3'),
    (3, 'Mepivacaine 3% plain', 'cartridges', 'countable', 'Henry Schein', 1.04, 'used', null, 24, 'X1'),
    (4, 'Topical anesthetic gel', 'jars', 'multi_use', 'Henry Schein', 16.50, 'open', 120, 24, null),
    (5, 'Needle 27g long', 'needles', 'countable', 'Henry Schein', 0.19, 'used', null, 60, null),
    (6, 'Needle 30g short', 'needles', 'countable', 'Henry Schein', 0.19, 'used', null, 60, null),
    (7, 'Composite A1', 'syringes', 'multi_use', 'Patterson Dental', 56.00, 'open', 8, 30, null),
    (8, 'Composite A2', 'syringes', 'multi_use', 'Patterson Dental', 56.00, 'open', 8, 30, 'L3'),
    (9, 'Composite A3', 'syringes', 'multi_use', 'Patterson Dental', 56.00, 'open', 8, 30, null),
    (10, 'Flowable composite A2', 'syringes', 'multi_use', 'Patterson Dental', 39.00, 'open', 15, 30, null),
    (11, 'Bonding agent', 'bottles', 'multi_use', 'Patterson Dental', 134.00, 'open', 70, 24, null),
    (12, 'Etch gel 37%', 'syringes', 'multi_use', 'Patterson Dental', 12.50, 'open', 20, 24, null),
    (13, 'Glass ionomer restorative', 'capsules', 'countable', 'Patterson Dental', 3.10, 'used', null, 24, 'E2'),
    (14, 'Temporary filling material', 'jars', 'multi_use', 'Patterson Dental', 27.00, 'open', 30, 30, null),
    (15, 'Temporary cement', 'kits', 'multi_use', 'Patterson Dental', 41.00, 'open', 20, 30, null),
    (16, 'Resin cement', 'syringes', 'multi_use', 'Patterson Dental', 96.00, 'open', 8, 18, null),
    (17, 'Matrix band', 'bands', 'countable', 'Patterson Dental', 0.48, 'used', null, 60, 'L2'),
    (18, 'Wedges', 'boxes', 'countable', 'Patterson Dental', 14.00, 'bulk', 0.02, 60, null),
    (19, 'Articulating paper', 'boxes', 'countable', 'Patterson Dental', 10.50, 'bulk', 0.03, 60, null),
    (20, 'Microbrushes', 'boxes', 'countable', 'Patterson Dental', 9.00, 'bulk', 0.06, 60, null),
    (21, 'K-files #15-40', 'packs', 'countable', 'Patterson Dental', 11.50, 'used', null, 60, null),
    (22, 'Rotary NiTi files', 'packs', 'countable', 'Patterson Dental', 72.00, 'used', null, 60, null),
    (23, 'Gutta percha points', 'boxes', 'countable', 'Patterson Dental', 12.00, 'bulk', 0.03, 48, null),
    (24, 'Paper points', 'boxes', 'countable', 'Patterson Dental', 9.50, 'bulk', 0.03, 48, 'M1'),
    (25, 'Root canal sealer', 'syringes', 'multi_use', 'Patterson Dental', 66.00, 'open', 10, 24, null),
    (26, 'Sodium hypochlorite', 'bottles', 'multi_use', 'Patterson Dental', 14.00, 'open', 12, 18, null),
    (27, 'Irrigation needles 30g', 'needles', 'countable', 'Patterson Dental', 0.72, 'used', null, 60, null),
    (28, 'Rubber dam latex-free', 'sheets', 'countable', 'Patterson Dental', 0.56, 'used', null, 48, 'O1'),
    (29, 'Alginate', 'bags', 'multi_use', 'Patterson Dental', 16.00, 'open', 14, 24, null),
    (30, 'PVS light body', 'cartridges', 'multi_use', 'Patterson Dental', 33.00, 'open', 4, 24, null),
    (31, 'PVS heavy body', 'cartridges', 'multi_use', 'Patterson Dental', 35.00, 'open', 3, 24, null),
    (32, 'Bite registration material', 'cartridges', 'multi_use', 'Patterson Dental', 30.00, 'open', 6, 24, null),
    (33, 'Mixing tips', 'tips', 'countable', 'Patterson Dental', 0.55, 'used', null, 60, null),
    (34, 'Triple trays', 'trays', 'countable', 'Patterson Dental', 1.25, 'used', null, 60, null),
    (35, 'Retraction cord #0', 'bottles', 'multi_use', 'Patterson Dental', 22.00, 'open', 30, 48, null),
    (36, 'Prophy paste medium', 'cups', 'countable', 'Sinclair Dental', 0.21, 'used', null, 30, null),
    (37, 'Prophy angle', 'angles', 'countable', 'Sinclair Dental', 0.46, 'used', null, 60, null),
    (38, 'Fluoride varnish 5%', 'doses', 'countable', 'Sinclair Dental', 1.15, 'used', null, 24, 'L4'),
    (39, 'Pit and fissure sealant', 'syringes', 'multi_use', 'Sinclair Dental', 46.00, 'idle', null, 24, null),
    (40, 'Desensitizer', 'bottles', 'multi_use', 'Sinclair Dental', 72.00, 'open', 40, 24, null),
    (41, 'Toothbrushes', 'boxes', 'countable', 'Sinclair Dental', 46.00, 'bulk', 0.1, 60, null),
    (42, 'Suture 4-0 chromic gut', 'sutures', 'countable', 'Sinclair Dental', 3.60, 'used', null, 36, null),
    (43, 'Gauze 2 x 2 in', 'packs', 'countable', 'Sinclair Dental', 6.20, 'bulk', 0.15, 60, null),
    (44, 'Collagen plugs', 'plugs', 'countable', 'Sinclair Dental', 9.60, 'used', null, 36, 'E1'),
    (45, 'Hemostatic gel', 'syringes', 'multi_use', 'Sinclair Dental', 41.00, 'open', 12, 24, null),
    (46, 'Scalpel blades #15', 'blades', 'countable', 'Sinclair Dental', 0.29, 'used', null, 60, null),
    (47, 'Dry socket paste', 'jars', 'multi_use', 'Sinclair Dental', 29.00, 'open', 20, 24, null),
    (48, 'Nitrile gloves S', 'boxes', 'countable', 'Henry Schein', 9.40, 'bulk', 0.25, 48, null),
    (49, 'Nitrile gloves M', 'boxes', 'countable', 'Henry Schein', 9.40, 'bulk', 0.6, 48, null),
    (50, 'Nitrile gloves L', 'boxes', 'countable', 'Henry Schein', 9.40, 'bulk', 0.3, 48, null),
    (51, 'Earloop masks level 3', 'boxes', 'countable', 'Henry Schein', 14.50, 'bulk', 0.7, 48, 'L1'),
    (52, 'N95 respirators', 'boxes', 'countable', 'Henry Schein', 31.00, 'bulk', 0.08, 48, null),
    (53, 'Isolation gowns', 'packs', 'countable', 'Henry Schein', 18.50, 'bulk', 0.1, 60, null),
    (54, 'Sterilization pouches 3.5 x 10 in', 'boxes', 'countable', 'Henry Schein', 16.00, 'bulk', 0.2, 60, null),
    (55, 'Sterilization pouches 7.5 x 13 in', 'boxes', 'countable', 'Henry Schein', 28.00, 'bulk', 0.08, 60, null),
    (56, 'Chemical indicators class 5', 'boxes', 'countable', 'Henry Schein', 48.00, 'bulk', 0.06, 36, null),
    (57, 'Spore tests', 'tests', 'countable', 'Henry Schein', 12.00, 'bulk', 0.2, 24, null),
    (58, 'Surface disinfectant wipes', 'canisters', 'multi_use', 'Henry Schein', 11.00, 'facility', 2, 24, null),
    (59, 'Ultrasonic cleaning solution', 'bottles', 'multi_use', 'Henry Schein', 35.00, 'facility', 12, 36, null),
    (60, 'Waterline treatment tablets', 'bottles', 'multi_use', 'Henry Schein', 89.00, 'facility', 25, 36, null),
    (61, 'Evacuation line cleaner', 'bottles', 'multi_use', 'Henry Schein', 38.00, 'facility', 10, 36, null),
    (62, 'Hand sanitizer', 'bottles', 'multi_use', 'Henry Schein', 9.00, 'facility', 5, 36, null),
    (63, 'Patient bibs', 'cases', 'countable', 'Sinclair Dental', 45.00, 'bulk', 0.03, 60, null),
    (64, 'Suction tips', 'bags', 'countable', 'Sinclair Dental', 9.00, 'bulk', 0.15, 60, null),
    (65, 'Saliva ejectors', 'bags', 'countable', 'Sinclair Dental', 6.50, 'bulk', 0.15, 60, null),
    (66, 'Air/water syringe tips', 'bags', 'countable', 'Sinclair Dental', 40.00, 'bulk', 0.06, 60, null),
    (67, 'Cotton rolls #2', 'boxes', 'countable', 'Sinclair Dental', 15.00, 'bulk', 0.02, 60, null),
    (68, 'Patient cups', 'sleeves', 'countable', 'Sinclair Dental', 6.00, 'bulk', 0.3, 60, null),
    (69, 'Headrest covers', 'boxes', 'countable', 'Sinclair Dental', 25.00, 'bulk', 0.06, 60, null),
    (70, 'Barrier film', 'rolls', 'countable', 'Sinclair Dental', 25.00, 'bulk', 0.1, 60, null),
    (71, 'Sensor sleeves', 'boxes', 'countable', 'Sinclair Dental', 30.00, 'bulk', 0.02, 60, 'B1'),
    (72, 'Sharps containers', 'containers', 'countable', 'Sinclair Dental', 8.00, 'bulk', 0.03, 60, null),
    (73, 'Handpiece lubricant', 'cans', 'multi_use', 'Sinclair Dental', 25.00, 'facility', 15, 36, null),
    (74, 'Distilled water', 'jugs', 'countable', 'Sinclair Dental', 3.50, 'bulk', 0.6, 24, null)
  ) s (n, name, unit, tracking, supplier, cost, kind, k, shelf, role)
  left join public.products p
    on p.clinic_id = c and p.archived_at is null and lower(btrim(p.name)) = lower(s.name);

  -- The catalog, each product once, as the catalog wrote it, and never stocked: the history can only start from 0, so
  -- it never runs twice.
  select string_agg(name, ', ' order by n) into v_wrong
  from demo_product
  where id is null or clinic_unit <> unit or clinic_tracking <> tracking;
  if v_wrong is not null or (select count(*) from demo_product) <> 74 then
    raise exception '% does not hold the general-practice catalog as make seed-catalog writes it (missing, renamed '
      'or changed: %): nothing was written.', v_clinic.name, coalesce(v_wrong, 'a product is there twice')
      using errcode = 'P0001';
  end if;
  select count(*), string_agg(x.name, ', ' order by x.n) filter (where x.rk <= 3) into v_count, v_wrong
  from (
    select p.n, p.name, row_number() over (order by p.n) as rk
    from demo_product p
    where exists (select 1 from public.transactions t where t.product_id = p.id)
       or exists (select 1 from public.batches b where b.product_id = p.id and b.qty <> 0)
       or exists (select 1 from public.open_items o where o.product_id = p.id)
       or exists (select 1 from public.to_buy_items t where t.product_id = p.id)
  ) x;
  if v_count > 0 then
    raise exception '% has stock, ledger rows or To buy lines on % catalog products already (%): the history only goes '
      'into a catalog never stocked, so nothing was written.', v_clinic.name, v_count,
      v_wrong || case when v_count > 3 then format(' and %s more', v_count - 3) else '' end
      using errcode = 'P0001';
  end if;
  select string_agg(p.name, ', ' order by p.name) into v_wrong
  from public.products p
  where p.clinic_id = c and p.archived_at is null
    and p.id not in (select id from demo_product)
    and lower(btrim(p.name)) not in ('pen', 'pain killer');
  if v_wrong is not null then
    raise exception '% has products outside the catalog besides Pen and Pain killer (%): delete them first, or '
      'nothing ends as the story says. Nothing was written.', v_clinic.name, v_wrong using errcode = 'P0001';
  end if;
  select string_agg(t.name, ', ' order by t.name) into v_wrong
  from public.procedure_templates t
  where t.clinic_id = c and t.archived_at is null
    and lower(t.name) in ('recall cleaning', 'composite filling', 'glass ionomer filling', 'extraction',
      'root canal', 'crown preparation', 'crown cementation', 'emergency exam');
  if v_wrong is not null then
    raise exception '% has procedures named as the story''s already (%): nothing was written.', v_clinic.name, v_wrong
      using errcode = 'P0001';
  end if;

  if v_dry_run then
    raise exception 'DEMO HISTORY PREVIEW: % (%), as its admin %: about six weeks of stock from Monday % to now (today '
      'is %), through the stock functions: suppliers on the 74 catalog products, 8 procedure templates, opening stock, '
      'deliveries, procedures, counts and bottles; then %; %. The ledger is append-only, so this stays in the clinic '
      'for good.',
      v_clinic.name, v_tz,
      (select coalesce(nullif(m.full_name, ''), m.email) from public.memberships m
       where m.clinic_id = c and m.user_id = v_admin),
      to_char(v_start, 'YYYY-MM-DD'), to_char(v_today, 'FMDay YYYY-MM-DD'),
      coalesce((select 'archives ' || string_agg(p.name, ' and ' order by p.name) || ' (Delete product)'
                from public.products p
                where p.clinic_id = c and p.archived_at is null and lower(btrim(p.name)) in ('pen', 'pain killer')),
               'archives nothing (no Pen or Pain killer)'),
      coalesce((select format('keeps the clinic''s own procedure templates (%s), listed after the story''s',
                         string_agg(t.name, ', ' order by t.created_at))
                from public.procedure_templates t where t.clinic_id = c and t.archived_at is null),
               'the clinic has no procedure templates of its own')
      using errcode = 'P0001';
  end if;

  -- Everything below is done as the admin, and the rows each step writes move back to the step's moment.
  perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  alter table public.transactions disable trigger transactions_append_only;

  -- The suppliers, as the Edit product sheet writes them.
  update public.products p set supplier = s.supplier from demo_product s where p.id = s.id;

  -- The plan ----------------------------------------------------------------------------------------------------------

  -- The working days from S to the last one before today (back 0), and today when the clinic is open (back -1).
  create temp table demo_day (d date primary key, nth integer not null, back integer not null) on commit drop;
  insert into demo_day (d, nth, back)
  select g.d, row_number() over (order by g.d) - 1, row_number() over (order by g.d desc) - 1
  from (select gs::date as d from generate_series(v_start, v_last, interval '1 day') gs) g
  where extract(isodow from g.d) < 6;
  if extract(isodow from v_today) < 6 then
    insert into demo_day (d, nth, back) values (v_today, (select max(nth) + 1 from demo_day), -1);
  end if;

  -- The procedure templates, as Edit procedure saves them; [product, default quantity], 0 for a multi-use product.
  create temp table demo_template (j integer primary key, name text not null, items jsonb not null, id uuid)
    on commit drop;
  insert into demo_template (j, name, items) values
    (1, 'Recall cleaning', '[["Prophy angle", 1], ["Prophy paste medium", 1], ["Fluoride varnish 5%", 1]]'),
    (2, 'Composite filling', '[["Septocaine 4% 1:100,000", 1], ["Needle 30g short", 1], ["Matrix band", 1],
      ["Topical anesthetic gel", 0], ["Etch gel 37%", 0], ["Bonding agent", 0], ["Composite A2", 0]]'),
    (3, 'Glass ionomer filling', '[["Glass ionomer restorative", 1], ["Matrix band", 1]]'),
    (4, 'Extraction', '[["Septocaine 4% 1:100,000", 2], ["Needle 27g long", 1], ["Suture 4-0 chromic gut", 1],
      ["Topical anesthetic gel", 0], ["Hemostatic gel", 0]]'),
    (5, 'Root canal', '[["Lidocaine 2% 1:100,000", 2], ["Needle 27g long", 1], ["Rubber dam latex-free", 1],
      ["K-files #15-40", 1], ["Rotary NiTi files", 1], ["Irrigation needles 30g", 2], ["Topical anesthetic gel", 0],
      ["Sodium hypochlorite", 0], ["Root canal sealer", 0], ["Temporary filling material", 0]]'),
    (6, 'Crown preparation', '[["Septocaine 4% 1:100,000", 2], ["Needle 30g short", 1], ["Mixing tips", 3],
      ["Triple trays", 1], ["Topical anesthetic gel", 0], ["Alginate", 0], ["Retraction cord #0", 0],
      ["PVS light body", 0], ["PVS heavy body", 0], ["Bite registration material", 0], ["Temporary cement", 0]]'),
    (7, 'Crown cementation', '[["Desensitizer", 0], ["Resin cement", 0]]'),
    (8, 'Emergency exam', '[["Lidocaine 2% 1:100,000", 1], ["Needle 30g short", 1], ["Topical anesthetic gel", 0],
      ["Temporary filling material", 0]]');

  -- Every step of the story, in time order. kind: opening (a supplier's opening delivery), template, open and finish
  -- (a bottle), procedure, edit (Edit usage, ref the procedure's seq), cancel (ref the procedure), count, adjust,
  -- dispose, add_expiry, order (ref the round: its day's nth), deliver (ref the round, per supplier), order_final.
  create temp table demo_event (
    seq bigserial primary key,
    at timestamptz not null,
    kind text not null,
    day date,
    j integer,
    rkey text,
    ref bigint,
    supplier text,
    product_id uuid,
    cancelled boolean not null default false,
    take_new uuid[] not null default '{}',
    qty numeric,
    note text,
    event_id uuid
  ) on commit drop;
  -- The supplies of each procedure and edit: [product name, quantity] in the order the screen lists them.
  create temp table demo_item (seq bigint not null, pos integer not null, name text not null, qty numeric not null)
    on commit drop;
  -- What each count changes, per product (bulk use since the last count, a shortfall, a box found).
  create temp table demo_count_line (seq bigint not null, product_id uuid not null, change numeric not null)
    on commit drop;
  -- What each round orders, per product, delivered two working days later.
  create temp table demo_order (round bigint not null, product_id uuid not null, qty numeric not null) on commit drop;

  -- S, before the practice opens: the opening deliveries, then the templates.
  insert into demo_event (at, kind, day, supplier)
  select (v_start + t) at time zone v_tz, 'opening', v_start, s
  from (values ('Henry Schein', time '07:15'), ('Patterson Dental', time '07:25'), ('Sinclair Dental', time '07:35'))
    o (s, t);
  insert into demo_event (at, kind, day, j)
  select (v_start + time '07:40' + make_interval(mins => j)) at time zone v_tz, 'template', v_start, j
  from demo_template;

  -- Procedures: how many of each a day (back keys them, so the last weeks read the same whatever the date), shuffled
  -- and spread from 8 am over the day, a few minutes apart at random.
  insert into demo_event (at, kind, day, j, rkey)
  select ((r.d + time '08:00') + (r.rk - 1) * (interval '510 minutes' / r.total)
          + make_interval(secs => floor(pg_temp.demo_rand('t:' || r.back || ':' || r.j || ':' || r.i) * 900)::int))
           at time zone v_tz,
         'procedure', r.d, r.j, r.back || ':' || r.j || ':' || r.i
  from (
    select p.*, row_number() over (partition by p.d order by p.o) as rk, count(*) over (partition by p.d) as total
    from (
      select n.d, n.back, n.j, g.i, pg_temp.demo_rand('o:' || n.back || ':' || n.j || ':' || g.i) as o
      from (
        select d.d, d.back, t.j,
               t.base + floor(pg_temp.demo_rand('n:' || d.back || ':' || t.j) * t.spread)::int as n
        from demo_day d
        cross join (values (1, 6, 3.0), (2, 2, 3.0), (3, 0, 2.6), (4, 0, 2.4), (5, 0, 1.9), (6, 0, 1.9), (7, 0, 1.8),
          (8, 0, 2.3)) t (j, base, spread)
      ) n
      cross join lateral generate_series(1, n.n) g (i)
    ) p
  ) r;

  -- A procedure logged by mistake and cancelled six minutes later: a filling, on the 17th working day.
  insert into demo_event (at, kind, day, j, rkey, cancelled)
  select (d + time '10:58') at time zone v_tz, 'procedure', d, 2, 'cancelled', true from demo_day where nth = 16;
  insert into demo_event (at, kind, day, ref)
  select at + interval '6 minutes', 'cancel', day, seq from demo_event where cancelled;

  insert into demo_item (seq, pos, name, qty)
  select e.seq, x.ord, x.value ->> 0, (x.value ->> 1)::numeric
  from demo_event e
  join demo_template t on t.j = e.j
  cross join lateral jsonb_array_elements(t.items) with ordinality x (value, ord)
  where e.kind = 'procedure';

  -- Adjust, then start: what a procedure changes on the template's list before it starts.
  -- Recall cleaning: about a third of the patients decline fluoride.
  delete from demo_item i using demo_event e
  where i.seq = e.seq and e.kind = 'procedure' and not e.cancelled and e.j = 1 and i.name = 'Fluoride varnish 5%'
    and pg_temp.demo_rand(e.rkey || ':1') < 0.35;
  -- Composite filling: the shade (A2 mostly, then A3, A1 now and then), a second cartridge, plain mepivacaine for a
  -- patient who should not have epinephrine, a rubber dam, a flowable liner.
  update demo_item i
  set name = case when pg_temp.demo_rand(e.rkey || ':1') >= 0.9 then 'Composite A1' else 'Composite A3' end
  from demo_event e
  where i.seq = e.seq and not e.cancelled and e.j = 2 and i.name = 'Composite A2'
    and pg_temp.demo_rand(e.rkey || ':1') >= 0.6;
  update demo_item i set name = 'Mepivacaine 3% plain'
  from demo_event e
  where i.seq = e.seq and not e.cancelled and e.j = 2 and i.name = 'Septocaine 4% 1:100,000'
    and pg_temp.demo_rand(e.rkey || ':2') < 0.05;
  update demo_item i set qty = 2
  from demo_event e
  where i.seq = e.seq and not e.cancelled and e.j = 2 and i.name = 'Septocaine 4% 1:100,000'
    and pg_temp.demo_rand(e.rkey || ':2') >= 0.05 and pg_temp.demo_rand(e.rkey || ':2') < 0.3;
  insert into demo_item (seq, pos, name, qty)
  select e.seq, 4, 'Rubber dam latex-free', 1
  from demo_event e
  where e.kind = 'procedure' and not e.cancelled and e.j = 2 and pg_temp.demo_rand(e.rkey || ':4') < 0.4;
  insert into demo_item (seq, pos, name, qty)
  select e.seq, 20, 'Flowable composite A2', 0
  from demo_event e
  where e.kind = 'procedure' and not e.cancelled and e.j = 2 and pg_temp.demo_rand(e.rkey || ':3') < 0.15;
  -- Glass ionomer filling: one in five needs anesthetic.
  insert into demo_item (seq, pos, name, qty)
  select e.seq, x.pos, x.name, x.qty
  from demo_event e
  cross join (values (-2, 'Septocaine 4% 1:100,000', 1), (-1, 'Needle 30g short', 1), (10, 'Topical anesthetic gel', 0))
    x (pos, name, qty)
  where e.kind = 'procedure' and e.j = 3 and pg_temp.demo_rand(e.rkey || ':1') < 0.2;
  -- Extraction: a third cartridge, a collagen plug for the socket, a blade for a surgical one.
  update demo_item i set qty = 3
  from demo_event e
  where i.seq = e.seq and e.j = 4 and i.name = 'Septocaine 4% 1:100,000' and pg_temp.demo_rand(e.rkey || ':1') < 0.15;
  insert into demo_item (seq, pos, name, qty)
  select e.seq, 4, 'Collagen plugs', 1
  from demo_event e where e.kind = 'procedure' and e.j = 4 and pg_temp.demo_rand(e.rkey || ':2') < 0.4;
  insert into demo_item (seq, pos, name, qty)
  select e.seq, 5, 'Scalpel blades #15', 1
  from demo_event e where e.kind = 'procedure' and e.j = 4 and pg_temp.demo_rand(e.rkey || ':3') < 0.2;
  -- Root canal: a third cartridge, a third irrigation needle.
  update demo_item i set qty = 3
  from demo_event e
  where i.seq = e.seq and e.j = 5 and i.name = 'Lidocaine 2% 1:100,000' and pg_temp.demo_rand(e.rkey || ':1') < 0.2;
  update demo_item i set qty = 3
  from demo_event e
  where i.seq = e.seq and e.j = 5 and i.name = 'Irrigation needles 30g' and pg_temp.demo_rand(e.rkey || ':2') < 0.3;
  -- Crown preparation: a third cartridge.
  update demo_item i set qty = 3
  from demo_event e
  where i.seq = e.seq and e.j = 6 and i.name = 'Septocaine 4% 1:100,000' and pg_temp.demo_rand(e.rkey || ':1') < 0.25;
  -- Emergency exam: a dry socket now and then (the paste only), and about a quarter without anesthetic.
  delete from demo_item i using demo_event e
  where i.seq = e.seq and e.j = 8
    and (pg_temp.demo_rand(e.rkey || ':1') < 0.1
      or (pg_temp.demo_rand(e.rkey || ':1') < 0.38
        and i.name in ('Lidocaine 2% 1:100,000', 'Needle 30g short', 'Topical anesthetic gel')));
  insert into demo_item (seq, pos, name, qty)
  select e.seq, 1, 'Dry socket paste', 0
  from demo_event e where e.kind = 'procedure' and e.j = 8 and pg_temp.demo_rand(e.rkey || ':1') < 0.1;

  -- Edit usage: on about half the days, one procedure is edited 15 to 40 minutes after it started (another cartridge,
  -- another suture or irrigation needle, or the fluoride a patient declined after all).
  insert into demo_event (at, kind, day, j, rkey, ref)
  select x.at + make_interval(mins => 15 + floor(pg_temp.demo_rand(x.rkey || ':m') * 25)::int), 'edit', x.day, x.j,
         x.rkey, x.seq
  from (
    select e.*, row_number() over (partition by e.day order by pg_temp.demo_rand(e.rkey || ':e')) as rk
    from demo_event e
    where e.kind = 'procedure' and not e.cancelled
      and (e.j in (2, 4, 5)
        or (e.j = 1 and exists (select 1 from demo_item i where i.seq = e.seq and i.name = 'Fluoride varnish 5%')))
  ) x
  join demo_day d on d.d = x.day
  where x.rk = 1 and pg_temp.demo_rand('edit:' || d.back) < 0.55;
  insert into demo_item (seq, pos, name, qty)
  select x.seq, i.pos, i.name,
         case
           when x.j = 2 and i.name in ('Septocaine 4% 1:100,000', 'Mepivacaine 3% plain') then i.qty + 1
           when x.j = 4 and i.name = 'Suture 4-0 chromic gut' then i.qty + 1
           when x.j = 5 and i.name = 'Irrigation needles 30g' then i.qty + 1
           else i.qty
         end
  from demo_event x
  join demo_item i on i.seq = x.ref
  where x.kind = 'edit' and not (x.j = 1 and i.name = 'Fluoride varnish 5%');

  -- Multi-use products used from the open one: the 1st, (k + 1)th, (2k + 1)th... procedure using a product takes a new
  -- one, and the open one is marked finished just before (both or neither, when today's procedure is still to come).
  create temp table demo_opening on commit drop as
  select u.seq, u.at, u.product_id, u.n
  from (
    select e.seq, e.at, p.id as product_id, p.k,
           row_number() over (partition by p.id order by e.at, e.seq) as n
    from demo_event e
    join demo_item i on i.seq = e.seq
    join demo_product p on p.name = i.name and p.kind = 'open'
    where e.kind = 'procedure' and not e.cancelled
  ) u
  where (u.n - 1) % u.k::integer = 0;
  update demo_event e set take_new = o.ids
  from (select seq, array_agg(product_id order by product_id) as ids from demo_opening group by seq) o
  where e.seq = o.seq;
  insert into demo_event (at, kind, day, product_id)
  select o.at - interval '3 minutes', 'finish', (o.at at time zone v_tz)::date, o.product_id
  from demo_opening o where o.n > 1 and o.at < v_now;
  -- The facility's bottles and canisters: opened on S before the practice opens, then the open one finished and a new
  -- one opened every k working days (both or neither, today).
  insert into demo_event (at, kind, day, product_id)
  select (v_start + time '07:50' + make_interval(secs => p.n)) at time zone v_tz, 'open', v_start, p.id
  from demo_product p where p.kind = 'facility';
  insert into demo_event (at, kind, day, product_id)
  select (d.d + x.t + make_interval(secs => p.n)) at time zone v_tz, x.kind, d.d, p.id
  from demo_product p
  join demo_day d on d.nth > 0 and d.nth % p.k::integer = 0
  cross join (values ('finish', time '07:45'), ('open', time '07:46')) x (kind, t)
  where p.kind = 'facility' and (d.d + time '07:46' + make_interval(secs => p.n)) at time zone v_tz < v_now;

  -- Counts: Fridays at 4 pm, and on the last working day at 4:10 pm (one count when that is a Friday).
  insert into demo_event (at, kind, day)
  select (d.d + case when d.back = 0 then time '16:10' else time '16:00' end) at time zone v_tz, 'count', d.d
  from demo_day d
  where d.back >= 0 and (extract(isodow from d.d) = 5 or d.back = 0);
  -- The bulk disposables lose the boxes used since the last count, at k a working day.
  insert into demo_count_line (seq, product_id, change)
  select x.seq, p.id, -(floor(p.k * (x.nth + 1)) - floor(p.k * (x.prev + 1)))
  from (
    select e.seq, d.nth, coalesce(lag(d.nth) over (order by e.at), -1) as prev
    from demo_event e join demo_day d on d.d = e.day
    where e.kind = 'count'
  ) x
  cross join demo_product p
  where p.kind = 'bulk' and floor(p.k * (x.nth + 1)) > floor(p.k * (x.prev + 1));
  -- Two small shortfalls a count among the supplies used by the piece.
  insert into demo_count_line (seq, product_id, change)
  select s.seq, s.id, -(1 + floor(pg_temp.demo_rand('s:' || s.back || ':' || s.n || ':q') * 3))
  from (
    select e.seq, d.back, p.id, p.n,
           row_number() over (partition by e.seq order by pg_temp.demo_rand('s:' || d.back || ':' || p.n)) as rk
    from demo_event e
    join demo_day d on d.d = e.day
    cross join demo_product p
    where e.kind = 'count'
      and p.name in ('Septocaine 4% 1:100,000', 'Needle 30g short', 'Needle 27g long', 'Prophy paste medium',
        'Prophy angle', 'Mixing tips', 'Triple trays', 'Suture 4-0 chromic gut')
  ) s
  where s.rk <= 2;
  -- The second count finds a box of sensor sleeves nobody had entered: undated, so Missing expiry, until the admin adds
  -- its expiry two working days later.
  insert into demo_count_line (seq, product_id, change)
  select e.seq, p.id, 1
  from (select seq from demo_event where kind = 'count' order by at offset 1 limit 1) e
  cross join demo_product p where p.role = 'B1';
  insert into demo_event (at, kind, day, product_id)
  select (d2.d + time '09:30') at time zone v_tz, 'add_expiry', d2.d, p.id
  from (select day from demo_event where kind = 'count' order by at offset 1 limit 1) e
  join demo_day d on d.d = e.day
  join demo_day d2 on d2.nth = d.nth + 2
  cross join demo_product p where p.role = 'B1';

  -- A dropped box of cartridges on the 13th working day, and the open box of rubber dam sheets written off at the end
  -- of the last one (Adjust, reason Damaged); the expired lot of mepivacaine disposed of first thing on the first
  -- working day after its month ended, before any procedure could take from it.
  insert into demo_event (at, kind, day, product_id, qty, note)
  select (d.d + time '10:20') at time zone v_tz, 'adjust', d.d, p.id, 6, 'Dropped a box, 6 cartridges cracked'
  from demo_day d cross join demo_product p where d.nth = 12 and p.role = 'D1';
  insert into demo_event (at, kind, day, product_id, note)
  select (v_last + time '16:50') at time zone v_tz, 'adjust', v_last, p.id, 'Box got wet'
  from demo_product p where p.role = 'O1';
  insert into demo_event (at, kind, day, product_id)
  select (d.d + time '07:55') at time zone v_tz, 'dispose', d.d, p.id
  from demo_product p
  cross join lateral (
    select coalesce(
      (select min(x.d) from demo_day x
       where x.back >= 0 and x.d >= (date_trunc('month', v_today - 35) + interval '1 month')::date),
      v_last) as d
  ) d
  where p.role = 'X1';

  -- Rounds: Mondays and Thursdays at 4:30 pm, delivered two working days later, each supplier at its hour; only rounds
  -- delivered by the last working day happen.
  insert into demo_event (at, kind, day, ref)
  select (d.d + time '16:30') at time zone v_tz, 'order', d.d, d.nth
  from demo_day d join demo_day v on v.nth = d.nth + 2 and v.back >= 0
  where d.back >= 0 and extract(isodow from d.d) in (1, 4);
  insert into demo_event (at, kind, day, ref, supplier)
  select (v.d + s.t) at time zone v_tz, 'deliver', v.d, d.nth, s.supplier
  from demo_day d
  join demo_day v on v.nth = d.nth + 2 and v.back >= 0
  cross join (values ('Henry Schein', time '10:15'), ('Patterson Dental', time '11:00'),
    ('Sinclair Dental', time '13:30')) s (supplier, t)
  where d.back >= 0 and extract(isodow from d.d) in (1, 4);
  select max(ref) into v_round_last from demo_event where kind = 'order';
  -- The last working day at 4:40 pm: the two lines marked Ordered at the end.
  insert into demo_event (at, kind, day) values ((v_last + time '16:40') at time zone v_tz, 'order_final', v_last);
  select at into v_final_count from demo_event where kind = 'count' and day = v_last;

  -- What the plan uses of each product, when: the measure a status reads (a countable's quantity, a multi-use
  -- product's unopened), so a round orders what will run short before the next delivery.
  create temp table demo_usage (at timestamptz not null, product_id uuid not null, qty numeric not null) on commit drop;
  insert into demo_usage (at, product_id, qty)
  select e.at, p.id, i.qty
  from demo_event e
  join demo_item i on i.seq = e.seq
  join demo_product p on p.name = i.name and p.tracking = 'countable'
  where e.kind = 'procedure' and not e.cancelled and i.qty > 0;
  insert into demo_usage (at, product_id, qty)
  select x.at, p.id, sum(case when i.seq = x.seq then i.qty else -i.qty end)
  from demo_event x
  join demo_item i on i.seq in (x.seq, x.ref)
  join demo_product p on p.name = i.name and p.tracking = 'countable'
  where x.kind = 'edit'
  group by x.seq, x.at, p.id
  having sum(case when i.seq = x.seq then i.qty else -i.qty end) <> 0;
  insert into demo_usage (at, product_id, qty)
  select o.at, o.product_id, 1 from demo_opening o
  union all
  select e.at, e.product_id, 1 from demo_event e where e.kind = 'open'
  union all
  select e.at, l.product_id, -l.change from demo_event e join demo_count_line l on l.seq = e.seq
  union all
  select e.at, e.product_id, e.qty from demo_event e where e.kind = 'adjust' and e.qty is not null;
  -- The expired lot holds what the opening put in it less what was used of it before the disposal.
  insert into demo_usage (at, product_id, qty)
  select e.at, e.product_id,
         greatest(22 - coalesce((select sum(u.qty) from demo_usage u where u.product_id = e.product_id and u.at < e.at), 0), 0)
  from demo_event e where e.kind = 'dispose';
  create index on demo_usage (product_id, at);

  -- The products the end state names land there from their last delivery (the landing round): the latest round from
  -- which the plan uses enough of them to bring a full stock down to the level they end at, at the end of the last
  -- working day (Earloop masks: at its last count; Rubber dam latex-free: just above its minimum when its box gets
  -- wet). After it they are left off the rounds.
  update demo_product p
  set desired = case p.role
        when 'L1' then p.minimum - 1
        when 'L2' then floor(p.minimum * 0.75)
        when 'L3' then p.minimum
        when 'L4' then floor(p.minimum * 0.8)
        when 'O1' then p.minimum + 3
      end,
      horizon = case p.role
        when 'L1' then v_final_count
        when 'O1' then (v_last + time '16:45') at time zone v_tz
        else (v_last + time '23:59') at time zone v_tz
      end
  where p.role in ('L1', 'L2', 'L3', 'L4', 'O1');
  update demo_product p
  set landing = coalesce(
    (select max(e.ref) from demo_event e
     where e.kind = 'order'
       and (select coalesce(sum(u.qty), 0) from demo_usage u
            where u.product_id = p.id and u.at > e.at and u.at <= p.horizon) >= p.target - p.desired + 1),
    (select min(e.ref) from demo_event e where e.kind = 'order'))
  where p.desired is not null;

  -- The story ----------------------------------------------------------------------------------------------------------

  for ev in select * from demo_event where at < v_now order by at, seq loop
    case ev.kind
    when 'opening' then
      -- Each product's opening stock, about its target (whole packs for the supplies used by the piece), in one lot
      -- (two for a product of two packs or more) whose expiry is 60% of its shelf life away. Mepivacaine has a partly
      -- used box whose lot expires within five weeks of today, Collagen plugs a lot that expires within about 30 days.
      select jsonb_agg(jsonb_build_object(
          'product_id', p.id, 'qty', l.qty, 'unit_cost', p.cost,
          'lot', case when p.kind <> 'bulk' then
            upper(left(regexp_replace(p.name, '[^A-Za-z]', '', 'g'), 2))
              || (10000 + floor(pg_temp.demo_rand('lot:' || p.n || ':' || l.k) * 89999))::integer end,
          'expiry_month', l.expiry) order by p.n, l.k)
      into v_lines
      from demo_product p
      cross join lateral (
        select x.k, x.qty, x.expiry
        from (
          select 1 as k,
                 case
                   when p.role = 'X1' then 22
                   when p.role = 'E1' then 30
                   when p.kind = 'used' and p.pack_size is not null and ceil(p.target / p.pack_size) >= 2
                     then (ceil(p.target / p.pack_size) - 1) * p.pack_size
                   when p.kind = 'used' and p.pack_size is not null then ceil(p.target / p.pack_size) * p.pack_size
                   else p.target
                 end as qty,
                 case
                   when p.role = 'X1' then date_trunc('month', v_today - 35)::date
                   when p.role = 'E1' then date_trunc('month', v_today + 5)::date
                   else date_trunc('month', v_start + make_interval(months => round(p.shelf * 0.6)::integer))::date
                 end as expiry
          union all
          select 2, case when p.role = 'X1' then 50 else p.pack_size end,
                 date_trunc('month', v_start + make_interval(months => round(p.shelf * 0.85)::integer))::date
          where p.role = 'X1'
             or (p.kind = 'used' and p.role is distinct from 'E1' and p.pack_size is not null
                 and ceil(p.target / p.pack_size) >= 2)
        ) x
      ) l
      where p.supplier = ev.supplier;
      perform public.stock_receive(c, v_lines, gen_random_uuid(), 'manual', null, 'Receive manually');

    when 'template' then
      select t.name,
             jsonb_agg(jsonb_build_object('product_id', p.id, 'default_qty', (x.value ->> 1)::numeric) order by x.ord)
      into v_wrong, v_items
      from demo_template t
      cross join lateral jsonb_array_elements(t.items) with ordinality x (value, ord)
      join demo_product p on p.name = x.value ->> 0
      where t.j = ev.j
      group by t.name;
      update demo_template set id = (public.procedure_template_save(c, null, v_wrong, v_items) ->> 'id')::uuid
      where j = ev.j;

    when 'procedure' then
      -- Countable supplies with their quantity, then the multi-use products at 0, as Start procedure sends them.
      select jsonb_agg(jsonb_build_object('product_id', p.id, 'qty', i.qty)
               order by (p.tracking = 'multi_use'), i.pos, i.name)
      into v_items
      from demo_item i join demo_product p on p.name = i.name
      where i.seq = ev.seq;
      select public.stock_procedure_start(c, t.id, t.name, v_items, ev.take_new, gen_random_uuid())
      into v_id
      from demo_template t where t.j = ev.j;
      update demo_event set event_id = v_id where seq = ev.seq;
      if (select count(*) from public.procedure_event_openings o where o.event_id = v_id)
         <> cardinality(ev.take_new) then
        raise exception 'Story: a % at % could not take a new bottle it should have', ev.rkey, ev.at;
      end if;

    when 'edit' then
      select jsonb_agg(jsonb_build_object('product_id', p.id, 'qty', i.qty)
               order by (p.tracking = 'multi_use'), i.pos, i.name)
      into v_items
      from demo_item i join demo_product p on p.name = i.name
      where i.seq = ev.seq;
      perform public.stock_procedure_edit(e.event_id, v_items, e.take_new, gen_random_uuid())
      from demo_event e where e.seq = ev.ref;

    when 'cancel' then
      perform public.stock_procedure_cancel(e.event_id, 'Logged by mistake', gen_random_uuid())
      from demo_event e where e.seq = ev.ref;

    when 'open' then
      perform public.bottle_open(ev.product_id, gen_random_uuid());

    when 'finish' then
      select o.id into v_id
      from public.open_items o
      where o.product_id = ev.product_id and o.finished_at is null
      order by o.opened_at, o.id
      limit 1;
      if v_id is null then
        raise exception 'Story: no open bottle of % to finish at %',
          (select name from demo_product where id = ev.product_id), ev.at;
      end if;
      perform public.bottle_finish(v_id, gen_random_uuid());

    when 'count' then
      select jsonb_agg(jsonb_build_object('product_id', l.product_id, 'counted', s.unopened + l.change) order by p.n),
             string_agg(p.name, ', ') filter (where s.unopened + l.change < 0)
      into v_lines, v_wrong
      from (select product_id, sum(change) as change from demo_count_line where seq = ev.seq group by product_id) l
      join public.product_stock s on s.product_id = l.product_id
      join demo_product p on p.id = l.product_id
      where l.change <> 0;
      if v_wrong is not null then
        raise exception 'Story: the count at % would find less than none of %', ev.at, v_wrong;
      end if;
      if v_lines is not null then
        perform public.stock_count_apply(c, v_lines, gen_random_uuid());
      end if;

    when 'adjust' then
      perform public.stock_adjust(ev.product_id, greatest(s.unopened - coalesce(ev.qty, s.unopened), 0), 'Damaged',
        ev.note, gen_random_uuid())
      from public.product_stock s where s.product_id = ev.product_id;

    when 'dispose' then
      select b.id, b.qty into v_id, v_qty
      from public.batches b
      where b.product_id = ev.product_id and b.expiry_month = date_trunc('month', v_today - 35)::date and b.qty > 0;
      if v_id is null then
        raise exception 'Story: the expired lot of % was used up before it could be disposed of', ev.product_id;
      end if;
      perform public.stock_dispose(v_id, v_qty, gen_random_uuid());

    when 'add_expiry' then
      perform public.batch_upsert(ev.product_id, null,
        date_trunc('month', ev.day + interval '40 months')::date, 1,
        'SS' || (10000 + floor(pg_temp.demo_rand('lot:found') * 89999))::integer, gen_random_uuid());

    when 'order' then
      -- What runs short before the next delivery (or, at the last round, by the end of today), up to the target in
      -- whole packs; a line the engine added is used as it is, the rest added by Add item; then Mark as ordered.
      v_ids := '{}';
      for pr in select * from demo_product order by n loop
        continue when pr.landing is not null and ev.ref > pr.landing;
        select s.quantity, s.unopened into v_qty, v_unopened from public.product_stock s where s.product_id = pr.id;
        v_measure := case when pr.tracking = 'multi_use' then v_unopened else v_qty end;
        select e.at into v_deliver from demo_event e
        where e.kind = 'deliver' and e.ref = ev.ref and e.supplier = pr.supplier;
        select coalesce(min(e.at), (v_today + time '23:59') at time zone v_tz) into v_next
        from demo_event e
        where e.kind = 'deliver' and e.ref > ev.ref and e.supplier = pr.supplier;
        select coalesce(sum(u.qty) filter (where u.at <= v_deliver), 0), coalesce(sum(u.qty), 0)
        into v_need_now, v_need_next
        from demo_usage u where u.product_id = pr.id and u.at > ev.at and u.at <= v_next;
        if pr.landing = ev.ref then
          select pr.desired + coalesce(sum(u.qty), 0) - v_measure into v_need
          from demo_usage u where u.product_id = pr.id and u.at > ev.at and u.at <= pr.horizon;
        elsif v_measure - v_need_next <= pr.minimum
           or exists (select 1 from public.to_buy_items t where t.product_id = pr.id and t.status = 'to_buy') then
          v_need := greatest(
            pr.target - (v_measure - v_need_now) - case when pr.tracking = 'multi_use' then 1 else 0 end,
            pr.minimum + 1 - (v_measure - v_need_next), 1);
          v_need := ceil(v_need / coalesce(pr.pack_size, 1)) * coalesce(pr.pack_size, 1);
        else
          v_need := 0;
        end if;
        -- The last delivery brings the short-dated boxes and the box received without its expiry.
        if ev.ref = v_round_last and pr.role in ('E2', 'E3', 'M1') then
          v_need := greatest(v_need, coalesce(pr.pack_size, 1));
        end if;
        continue when v_need <= 0;
        select t.id into v_id from public.to_buy_items t where t.product_id = pr.id and t.status = 'to_buy';
        if v_id is null then
          v_id := (public.to_buy_add(c, pr.id) ->> 'id')::uuid;
        end if;
        update public.to_buy_items set qty = v_need, qty_edited = true where id = v_id;
        v_ids := v_ids || v_id;
        insert into demo_order (round, product_id, qty) values (ev.ref, pr.id, v_need);
      end loop;
      if cardinality(v_ids) > 0 then
        perform public.to_buy_mark_ordered(c, v_ids);
      end if;

    when 'deliver' then
      -- One delivery per supplier: lots of the day, expiry months a shelf life away; the short-dated boxes and the box
      -- received without its expiry at the last one.
      select jsonb_agg(jsonb_build_object(
          'product_id', p.id, 'qty', o.qty, 'unit_cost', p.cost,
          'lot', case
            when ev.ref = v_round_last and p.role = 'M1' then null
            when p.kind = 'bulk' then null
            else upper(left(regexp_replace(p.name, '[^A-Za-z]', '', 'g'), 2))
              || (10000 + floor(pg_temp.demo_rand('lot:' || p.n || ':' || ev.day) * 89999))::integer
          end,
          'expiry_month', case
            when ev.ref = v_round_last and p.role = 'M1' then null
            when ev.ref = v_round_last and p.role = 'E2' then date_trunc('month', v_today + 40)::date
            when ev.ref = v_round_last and p.role = 'E3' then date_trunc('month', v_today + 58)::date
            else date_trunc('month', ev.day + make_interval(months => p.shelf))::date
          end) order by p.n)
      into v_lines
      from demo_order o join demo_product p on p.id = o.product_id
      where o.round = ev.ref and p.supplier = ev.supplier;
      if v_lines is not null then
        perform public.stock_receive(c, v_lines, gen_random_uuid(), 'manual', null, 'Receive manually');
      end if;

    when 'order_final' then
      select array_agg(t.id) into v_ids
      from public.to_buy_items t join demo_product p on p.id = t.product_id
      where t.status = 'to_buy' and p.role in ('L1', 'L2');
      if coalesce(cardinality(v_ids), 0) <> 2 then
        raise exception 'Story: Earloop masks level 3 and Matrix band are not both on To buy at the end';
      end if;
      perform public.to_buy_mark_ordered(c, v_ids);
    end case;

    -- The rows this step wrote carry now(): move them to the step's moment.
    update public.transactions set at = ev.at, created_at = ev.at where clinic_id = c and at = now();
    update public.stock_actions set created_at = ev.at where clinic_id = c and created_at = now();
    update public.batches set created_at = ev.at where clinic_id = c and created_at = now();
    update public.open_items set opened_at = ev.at, created_at = ev.at where clinic_id = c and created_at = now();
    update public.open_items set finished_at = ev.at where clinic_id = c and finished_at = now();
    update public.procedure_events set started_at = ev.at, created_at = ev.at where clinic_id = c and started_at = now();
    update public.procedure_events set cancelled_at = ev.at where clinic_id = c and cancelled_at = now();
    update public.procedure_event_items set created_at = ev.at where clinic_id = c and created_at = now();
    update public.procedure_event_openings set created_at = ev.at where clinic_id = c and created_at = now();
    update public.procedure_templates set created_at = ev.at where clinic_id = c and created_at = now();
    update public.procedure_template_items set created_at = ev.at where clinic_id = c and created_at = now();
    update public.to_buy_items set created_at = ev.at where clinic_id = c and created_at = now();
    update public.to_buy_items set ordered_at = ev.at where clinic_id = c and ordered_at = now();
    update public.to_buy_items set received_at = ev.at where clinic_id = c and received_at = now();
    update public.alerts set opened_at = ev.at, created_at = ev.at where clinic_id = c and created_at = now();
    update public.alerts set resolved_at = ev.at where clinic_id = c and resolved_at = now();
  end loop;

  -- Today, as now -------------------------------------------------------------------------------------------------------

  -- Pen and Pain killer, Grigor's test products, deleted as the app deletes a product: archived with their history and
  -- whatever they hold, taken off the templates and To buy.
  perform public.product_archive(p.id)
  from public.products p
  where p.clinic_id = c and p.archived_at is null and lower(btrim(p.name)) in ('pen', 'pain killer');

  -- The nightly status refresh, as now, so the alerts match.
  perform public.refresh_product(p.id) from public.products p where p.clinic_id = c and p.archived_at is null;

  -- An expiring alert opens on the day its batch crosses the threshold (the nightly refresh, 07:00 UTC), not on the day
  -- the batch was received, as seed-demo.sql has it.
  update public.alerts a
  set opened_at = x.crossed, created_at = x.crossed
  from (
    select a2.id, least(v_now, ((((b.expiry_month + interval '1 month' - interval '1 day')::date - a2.threshold_days)
             + time '07:00') at time zone 'UTC')) as crossed
    from public.alerts a2 join public.batches b on b.id = a2.batch_id
    where a2.clinic_id = c and a2.kind = 'expiring'
  ) x
  where a.id = x.id and x.crossed > a.opened_at;

  -- No push goes out for the history. The pushes its alerts queued move to their alert's time and are marked as
  -- push_claim marks one that will never be sent: its alert closed, its product archived, or due over a day ago. The
  -- clinic's older pushes (the test products') get the same marks, so nothing of the clinic waits to be sent.
  update public.push_outbox o
  set created_at = a.opened_at, not_before = least(v_now, engine.push_waking_time(a.opened_at, v_tz))
  from public.alerts a
  where a.id = o.alert_id and o.clinic_id = c and o.created_at = now() and o.sent_at is null and o.skipped is null;
  update public.push_outbox o
  set skipped = case
      when a.resolved_at is not null then 'resolved'
      when p.archived_at is not null then 'archived'
      else 'stale'
    end
  from public.alerts a
  left join public.products p on p.id = a.product_id
  where a.id = o.alert_id and o.clinic_id = c and o.sent_at is null and o.skipped is null;

  alter table public.transactions enable trigger transactions_append_only;

  -- The end state, or nothing ------------------------------------------------------------------------------------------

  select string_agg(format('%s reads %s', p.name, s.status), '; ' order by p.n) into v_wrong
  from demo_product p join public.product_status s on s.product_id = p.id
  where s.status <> case
      when p.role in ('L1', 'L2', 'L3', 'L4') then 'low'
      when p.role = 'O1' then 'out_of_stock'
      when p.role in ('E1', 'E2', 'E3') then 'expiring'
      when p.role = 'M1' then 'missing_expiry'
      else 'healthy'
    end;
  if v_wrong is not null then
    raise exception 'Story: the end state differs (%): nothing was written.', v_wrong;
  end if;
  select string_agg(format('%s %s', p.name, t.status), '; ') into v_wrong
  from public.to_buy_items t join public.products p on p.id = t.product_id
  left join demo_product d on d.id = t.product_id
  where t.clinic_id = c and t.status in ('to_buy', 'ordered')
    and (d.role is null
      or t.status::text <> case when d.role in ('L1', 'L2') then 'ordered' when d.role in ('L3', 'L4', 'O1') then 'to_buy' end);
  if v_wrong is not null
     or (select count(*) from public.to_buy_items t where t.clinic_id = c and t.status in ('to_buy', 'ordered')) <> 5
  then
    raise exception 'Story: To buy differs (%): nothing was written.', coalesce(v_wrong, 'lines missing');
  end if;
  if (select (a.to_buy_count, a.expiring_batch_count, a.missing_expiry_product_count)
      from public.clinic_attention a where a.clinic_id = c) <> (3, 3, 1)
  then
    raise exception 'Story: Home does not read 3 To buy, 3 Expiring soon, 1 Missing expiry: nothing was written.';
  end if;
  select string_agg(p.name, ', ' order by p.n) into v_wrong
  from demo_product p join public.product_stock s on s.product_id = p.id
  where p.kind in ('open', 'facility') and s.open_count <> 1
    and exists (select 1 from demo_usage u where u.product_id = p.id);
  if v_wrong is not null then
    raise exception 'Story: these multi-use products do not have one bottle open: %. Nothing was written.', v_wrong;
  end if;
  select string_agg(p.name, ', ') into v_wrong
  from demo_product p join public.product_stock s on s.product_id = p.id
  where s.quantity <> (select coalesce(sum(t.delta), 0) from public.transactions t where t.product_id = p.id);
  if v_wrong is not null then
    raise exception 'Story: the ledger does not end at the stock for %: nothing was written.', v_wrong;
  end if;
  if exists (select 1 from public.alerts a where a.clinic_id = c and a.resolved_at < a.opened_at)
     or exists (select 1 from public.transactions t
                where t.clinic_id = c and t.product_id in (select id from demo_product)
                  and (t.at > v_now or t.at < (v_start + time '07:00') at time zone v_tz))
     or exists (select 1 from public.push_outbox o
                where o.clinic_id = c and o.sent_at is null and o.skipped is null)
  then
    raise exception 'Story: an alert closes before it opens, a ledger row falls outside the story or a push waits to '
      'be sent: nothing was written.';
  end if;
  if (select t.tgenabled from pg_catalog.pg_trigger t
      where t.tgrelid = 'public.transactions'::regclass and t.tgname = 'transactions_append_only') <> 'O'
  then
    raise exception 'Story: the ledger''s append-only trigger is not back on: nothing was written.';
  end if;

  drop function pg_temp.demo_rand(text);
end;
$$;
