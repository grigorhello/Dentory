-- Starting catalog: a small Canadian general practice (two or three operatories, a dentist or two, hygienists).
-- 74 products over the ten default categories (MS-100 D13), written as an admin would type them on New product
-- (MS-117): no supplier, location or cost, which are the clinic's to fill (receiving sets the cost), and no stock.
-- Every product starts at 0; the clinic's first delivery, Receive manually, Adjust or Count stock sets its quantity.
-- supabase/catalogs/README.md says what the clinic sees until then and how to adapt a copy of this file.
--
-- Run it with `make seed-catalog CLINIC_ID=<uuid> [TARGET=local|linked]`, which puts the clinic's id where
-- __CLINIC_ID__ stands below and sends the file to the database (`supabase db query`, so it works on a hosted project
-- through the Management API with no key). It adds only the categories and products the clinic does not have yet:
-- names are matched without regard to case, archived products included, so nothing the clinic deleted comes back,
-- and nothing that exists is changed. It writes no batches, ledger rows, open items or To buy lines. An id no clinic
-- has is refused. It is a single statement, so Postgres runs it as one transaction: if any part fails, nothing is
-- added.
--
-- One product per line: position (the order the products join the clinic, one millisecond apart, which To buy keeps),
-- category, name, counted-in unit, received-as pack and its size (only where nearly every brand sells the same pack),
-- minimum, target, tracking. Single items are counted where a procedure uses a set number of them (cartridges,
-- needles, capsules, doses, sutures); bulk disposables in the box, bag, pack or case they are stored in; multi-use
-- products (opened and used across patients, MS-100 G1) in containers, whose minimum counts spares (G3).
with
  catalog (position, category, name, unit, pack_unit, pack_size, minimum, target, tracking) as (
    values
      (1, 'Anesthetic', 'Septocaine 4% 1:100,000', 'cartridges', 'box', 50, 50, 150, 'countable'),
      (2, 'Anesthetic', 'Lidocaine 2% 1:100,000', 'cartridges', 'box', 50, 50, 100, 'countable'),
      (3, 'Anesthetic', 'Mepivacaine 3% plain', 'cartridges', 'box', 50, 20, 50, 'countable'),
      (4, 'Anesthetic', 'Topical anesthetic gel', 'jars', null, null, 0, 2, 'multi_use'),
      (5, 'Anesthetic', 'Needle 27g long', 'needles', 'box', 100, 50, 200, 'countable'),
      (6, 'Anesthetic', 'Needle 30g short', 'needles', 'box', 100, 50, 200, 'countable'),
      (7, 'Restorative', 'Composite A1', 'syringes', null, null, 0, 2, 'multi_use'),
      (8, 'Restorative', 'Composite A2', 'syringes', null, null, 2, 6, 'multi_use'),
      (9, 'Restorative', 'Composite A3', 'syringes', null, null, 1, 4, 'multi_use'),
      (10, 'Restorative', 'Flowable composite A2', 'syringes', null, null, 1, 4, 'multi_use'),
      (11, 'Restorative', 'Bonding agent', 'bottles', null, null, 1, 3, 'multi_use'),
      (12, 'Restorative', 'Etch gel 37%', 'syringes', null, null, 2, 6, 'multi_use'),
      (13, 'Restorative', 'Glass ionomer restorative', 'capsules', 'box', 50, 10, 50, 'countable'),
      (14, 'Restorative', 'Temporary filling material', 'jars', null, null, 0, 2, 'multi_use'),
      (15, 'Restorative', 'Temporary cement', 'kits', null, null, 0, 2, 'multi_use'),
      (16, 'Restorative', 'Resin cement', 'syringes', null, null, 0, 2, 'multi_use'),
      (17, 'Restorative', 'Matrix band', 'bands', null, null, 24, 72, 'countable'),
      (18, 'Restorative', 'Wedges', 'boxes', null, null, 1, 2, 'countable'),
      (19, 'Restorative', 'Articulating paper', 'boxes', null, null, 1, 2, 'countable'),
      (20, 'Restorative', 'Microbrushes', 'boxes', null, null, 1, 3, 'countable'),
      (21, 'Endodontics', 'K-files #15-40', 'packs', null, null, 2, 6, 'countable'),
      (22, 'Endodontics', 'Rotary NiTi files', 'packs', null, null, 2, 6, 'countable'),
      (23, 'Endodontics', 'Gutta percha points', 'boxes', null, null, 1, 2, 'countable'),
      (24, 'Endodontics', 'Paper points', 'boxes', null, null, 1, 2, 'countable'),
      (25, 'Endodontics', 'Root canal sealer', 'syringes', null, null, 0, 2, 'multi_use'),
      (26, 'Endodontics', 'Sodium hypochlorite', 'bottles', null, null, 0, 2, 'multi_use'),
      (27, 'Endodontics', 'Irrigation needles 30g', 'needles', null, null, 10, 50, 'countable'),
      (28, 'Endodontics', 'Rubber dam latex-free', 'sheets', null, null, 10, 36, 'countable'),
      (29, 'Impression', 'Alginate', 'bags', null, null, 1, 3, 'multi_use'),
      (30, 'Impression', 'PVS light body', 'cartridges', null, null, 1, 4, 'multi_use'),
      (31, 'Impression', 'PVS heavy body', 'cartridges', null, null, 1, 4, 'multi_use'),
      (32, 'Impression', 'Bite registration material', 'cartridges', null, null, 0, 2, 'multi_use'),
      (33, 'Impression', 'Mixing tips', 'tips', null, null, 25, 100, 'countable'),
      (34, 'Impression', 'Triple trays', 'trays', null, null, 10, 40, 'countable'),
      (35, 'Impression', 'Retraction cord #0', 'bottles', null, null, 0, 2, 'multi_use'),
      (36, 'Preventive', 'Prophy paste medium', 'cups', 'box', 200, 60, 200, 'countable'),
      (37, 'Preventive', 'Prophy angle', 'angles', 'box', 100, 60, 200, 'countable'),
      (38, 'Preventive', 'Fluoride varnish 5%', 'doses', null, null, 25, 100, 'countable'),
      (39, 'Preventive', 'Pit and fissure sealant', 'syringes', null, null, 0, 2, 'multi_use'),
      (40, 'Preventive', 'Desensitizer', 'bottles', null, null, 0, 2, 'multi_use'),
      (41, 'Preventive', 'Toothbrushes', 'boxes', null, null, 1, 3, 'countable'),
      (42, 'Surgical', 'Suture 4-0 chromic gut', 'sutures', null, null, 6, 24, 'countable'),
      (43, 'Surgical', 'Gauze 2 x 2 in', 'packs', null, null, 2, 6, 'countable'),
      (44, 'Surgical', 'Collagen plugs', 'plugs', 'box', 10, 5, 20, 'countable'),
      (45, 'Surgical', 'Hemostatic gel', 'syringes', null, null, 0, 2, 'multi_use'),
      (46, 'Surgical', 'Scalpel blades #15', 'blades', 'box', 100, 10, 100, 'countable'),
      (47, 'Surgical', 'Dry socket paste', 'jars', null, null, 0, 2, 'multi_use'),
      (48, 'PPE', 'Nitrile gloves S', 'boxes', 'case', 10, 2, 6, 'countable'),
      (49, 'PPE', 'Nitrile gloves M', 'boxes', 'case', 10, 4, 12, 'countable'),
      (50, 'PPE', 'Nitrile gloves L', 'boxes', 'case', 10, 2, 6, 'countable'),
      (51, 'PPE', 'Earloop masks level 3', 'boxes', null, null, 4, 12, 'countable'),
      (52, 'PPE', 'N95 respirators', 'boxes', null, null, 1, 3, 'countable'),
      (53, 'PPE', 'Isolation gowns', 'packs', null, null, 1, 3, 'countable'),
      (54, 'Sterilization', 'Sterilization pouches 3.5 x 10 in', 'boxes', null, null, 2, 6, 'countable'),
      (55, 'Sterilization', 'Sterilization pouches 7.5 x 13 in', 'boxes', null, null, 1, 3, 'countable'),
      (56, 'Sterilization', 'Chemical indicators class 5', 'boxes', null, null, 1, 2, 'countable'),
      (57, 'Sterilization', 'Spore tests', 'tests', null, null, 4, 12, 'countable'),
      (58, 'Sterilization', 'Surface disinfectant wipes', 'canisters', 'case', 12, 4, 12, 'multi_use'),
      (59, 'Sterilization', 'Ultrasonic cleaning solution', 'bottles', null, null, 0, 2, 'multi_use'),
      (60, 'Sterilization', 'Waterline treatment tablets', 'bottles', null, null, 0, 2, 'multi_use'),
      (61, 'Sterilization', 'Evacuation line cleaner', 'bottles', null, null, 0, 2, 'multi_use'),
      (62, 'Sterilization', 'Hand sanitizer', 'bottles', null, null, 1, 4, 'multi_use'),
      (63, 'Disposable', 'Patient bibs', 'cases', null, null, 1, 2, 'countable'),
      (64, 'Disposable', 'Suction tips', 'bags', null, null, 1, 4, 'countable'),
      (65, 'Disposable', 'Saliva ejectors', 'bags', null, null, 2, 6, 'countable'),
      (66, 'Disposable', 'Air/water syringe tips', 'bags', null, null, 1, 4, 'countable'),
      (67, 'Disposable', 'Cotton rolls #2', 'boxes', null, null, 1, 2, 'countable'),
      (68, 'Disposable', 'Patient cups', 'sleeves', null, null, 4, 12, 'countable'),
      (69, 'Disposable', 'Headrest covers', 'boxes', null, null, 1, 3, 'countable'),
      (70, 'Disposable', 'Barrier film', 'rolls', null, null, 1, 4, 'countable'),
      (71, 'Disposable', 'Sensor sleeves', 'boxes', null, null, 1, 2, 'countable'),
      (72, 'Other', 'Sharps containers', 'containers', null, null, 1, 3, 'countable'),
      (73, 'Other', 'Handpiece lubricant', 'cans', null, null, 0, 2, 'multi_use'),
      (74, 'Other', 'Distilled water', 'jugs', null, null, 2, 6, 'countable')
  ),
  -- The clinic, or the refusal before anything is written: every insert below takes its id from here.
  clinic as (
    select coalesce(
      (select c.id from public.clinics c where c.id = '__CLINIC_ID__'),
      engine.fail('P0002', 'No clinic has the id __CLINIC_ID__: nothing was added.')::text::uuid
    ) as id
  ),
  -- A category the clinic lacks (by name, without regard to case) is added after its last one, as New category does.
  new_categories as (
    insert into public.categories (clinic_id, name, position)
    select clinic.id, wanted.name,
      (select coalesce(max(c.position), 0) from public.categories c where c.clinic_id = clinic.id)
        + row_number() over (order by wanted.first_position)
    from (select k.category as name, min(k.position) as first_position from catalog k group by k.category) wanted
    cross join clinic
    where not exists (
      select 1 from public.categories c where c.clinic_id = clinic.id and lower(c.name) = lower(wanted.name)
    )
    returning id, name
  ),
  clinic_categories as (
    select c.id, c.name from public.categories c join clinic on c.clinic_id = clinic.id
    union all
    select n.id, n.name from new_categories n
  ),
  new_products as (
    insert into public.products (
      clinic_id, name, category_id, unit, pack_unit, pack_size, minimum, target, tracking, created_at
    )
    select clinic.id, k.name,
      (select cc.id from clinic_categories cc where lower(cc.name) = lower(k.category) limit 1),
      k.unit, k.pack_unit, k.pack_size, k.minimum, k.target, k.tracking::public.tracking_mode,
      now() + (k.position - 1) * interval '1 millisecond'
    from catalog k
    cross join clinic
    where not exists (
      select 1 from public.products p where p.clinic_id = clinic.id and lower(btrim(p.name)) = lower(k.name)
    )
    order by k.position
    returning id
  )
select
  (select count(*) from new_categories) as categories_added,
  (select count(*) from new_products) as products_added,
  (select c.name from public.clinics c join clinic on c.id = clinic.id) as clinic;
