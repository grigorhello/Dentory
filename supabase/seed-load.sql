-- MS-150 · The load-test clinic "Load test dental": 500 products and about 5,000 ledger rows over six months, for the
-- performance figures of PRD §9 (`make perf-report`, docs/runbooks/performance.md).
--
-- Run after a reset, with or without the demo clinic: `make db-reset seed-load`, or `make db-reset seed-demo seed-load`.
-- Local stack only; never run it against a hosted project.
--
-- Everything is fixed: the ids of the clinic, its people, products and templates, the idempotency keys and every
-- choice the story makes (a hash of the step, never random()), so two runs on the same day write the same clinic; on
-- another day the weekdays fall on other dates and the figures move by a few rows. Stock moves only
-- through the MS-106 functions and the To buy functions, called as the member the story names, so batches, open items,
-- the ledger, alerts and To buy lines are what the engine writes; after each step its rows move back to the step's
-- time, timestamps only, as seed-demo.sql does (pg_temp.backdate), with the ledger's append-only trigger off until the
-- end. The story ends yesterday, so nothing is dated after the moment it ran.
--
-- The clinic: 50 kinds of supply in the ten categories (MS-100 D13), ten sizes, shades or makes each; 36% multi-use;
-- packs of 10 to 1,000 for the consumables; four consumables every procedure uses (gloves, bibs, suction tips, cotton
-- rolls), so procedures started at once lock the same products. Opening stock 180 days ago, lots and expiries on most
-- batches, undated stock on about one product in seven, a few batches already expired. Then each working day: three or
-- four procedures from 20 templates (some edited, a few cancelled), bottles opened and finished, now and then an
-- adjustment; on Tuesdays a staff member adds to To buy, on Wednesdays an admin disposes expired stock and marks the
-- To buy lines ordered, which arrive on Monday; a count of 80 products every month. Two invoices wait on Receive
-- delivery: one read, one that could not be read.
--
-- Sign in as olivia@loadtest.example (Admin) or hannah@loadtest.example (Staff), password "loadtest".

begin;

do $$
begin
  if exists (select 1 from public.clinics where id = '10ad0000-0000-4000-8000-000000000001') then
    raise exception 'The load clinic is already there. Run make db-reset first.';
  end if;
end;
$$;

-- Helpers ------------------------------------------------------------------------------------------------------------

create function pg_temp.clinic() returns uuid language sql immutable as $$ select '10ad0000-0000-4000-8000-000000000001'::uuid $$;
-- People 1-5, products 1-500, templates 1-20.
create function pg_temp.member(n int) returns uuid language sql immutable as $$ select ('10ad0000-0000-4000-8000-0001' || lpad(n::text, 8, '0'))::uuid $$;
create function pg_temp.pid(n int) returns uuid language sql immutable as $$ select ('10ad0000-0000-4000-8000-0002' || lpad(n::text, 8, '0'))::uuid $$;
create function pg_temp.tid(n int) returns uuid language sql immutable as $$ select ('10ad0000-0000-4000-8000-0003' || lpad(n::text, 8, '0'))::uuid $$;
create function pg_temp.invoice(n int) returns uuid language sql immutable as $$ select ('10ad0000-0000-4000-8000-0004' || lpad(n::text, 8, '0'))::uuid $$;
-- The number of a product of this clinic, from its id.
create function pg_temp.pnum(p_id uuid) returns int language sql immutable as $$ select substr(p_id::text, 29)::int $$;

-- A fixed number in [0, 1) for a named choice of the story.
create function pg_temp.rnd(p_key text) returns double precision language sql immutable as $$
  select ('x' || substr(md5('load:' || p_key), 1, 8))::bit(32)::bigint / 4294967296.0
$$;
-- A whole number from p_low to p_high for a named choice.
create function pg_temp.pick(p_key text, p_low int, p_high int) returns int language sql immutable as $$
  select p_low + floor(pg_temp.rnd(p_key) * (p_high - p_low + 1))::int
$$;
-- The idempotency key of a step.
create function pg_temp.key(p_step text) returns uuid language sql immutable as $$ select md5('load-key:' || p_step)::uuid $$;

create function pg_temp.today() returns date language sql stable as $$ select (now() at time zone 'America/Vancouver')::date $$;
-- A moment p_days ago at p_minute minutes past midnight, clinic time. The story's days are 1 to 180 days ago.
create function pg_temp.at(p_days int, p_minute int) returns timestamptz language sql stable as $$
  select ((pg_temp.today() - p_days) + make_interval(mins => p_minute)) at time zone 'America/Vancouver'
$$;
-- The expiry month that holds the day p_days from today.
create function pg_temp.expiry_in(p_days int) returns date language sql stable as $$
  select date_trunc('month', pg_temp.today() + p_days)::date
$$;

create function pg_temp.act_as(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true)
$$;

-- Every row the last step wrote still carries now() (the whole seed is one transaction); move them to p_at. The ledger
-- and the procedures are found through their time indexes, the rest are small.
create function pg_temp.backdate(p_at timestamptz) returns void language plpgsql as $$
declare
  c uuid := pg_temp.clinic();
begin
  update public.transactions set at = p_at, created_at = p_at where clinic_id = c and at = now() and created_at = now();
  update public.stock_actions set created_at = p_at where clinic_id = c and created_at = now();
  update public.batches set created_at = p_at where clinic_id = c and created_at = now();
  update public.open_items set opened_at = p_at, created_at = p_at where clinic_id = c and created_at = now();
  update public.open_items set finished_at = p_at where clinic_id = c and finished_at = now();
  update public.procedure_events set started_at = p_at, created_at = p_at where clinic_id = c and started_at = now();
  update public.procedure_events set cancelled_at = p_at where clinic_id = c and cancelled_at = now();
  update public.procedure_event_items set created_at = p_at where clinic_id = c and created_at = now();
  update public.procedure_event_openings set created_at = p_at where clinic_id = c and created_at = now();
  update public.to_buy_items set created_at = p_at where clinic_id = c and created_at = now();
  update public.to_buy_items set ordered_at = p_at where clinic_id = c and ordered_at = now();
  update public.to_buy_items set received_at = p_at where clinic_id = c and received_at = now();
  update public.alerts set opened_at = p_at, created_at = p_at where clinic_id = c and created_at = now();
  update public.alerts set resolved_at = p_at where clinic_id = c and resolved_at = now();
end;
$$;

-- Backdating rewrites timestamps of rows this transaction wrote; the trigger is back on before commit.
alter table public.transactions disable trigger transactions_append_only;

-- Clinic and people ----------------------------------------------------------------------------------------------------

insert into public.clinics (id, name, city, country, currency, time_zone, trial_ends_at)
values (pg_temp.clinic(), 'Load test dental', 'Vancouver', 'CA', 'CAD', 'America/Vancouver', now() + interval '90 days');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select pg_temp.member(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', email,
  extensions.crypt('loadtest', extensions.gen_salt('bf')), now(),
  '{"provider": "email", "providers": ["email"]}', jsonb_build_object('full_name', full_name), now(), now(),
  '', '', '', ''
from (values
  (1, 'olivia@loadtest.example', 'Olivia Grant'),
  (2, 'marcus@loadtest.example', 'Dr. Marcus Lee'),
  (3, 'hannah@loadtest.example', 'Hannah Cole'),
  (4, 'ravi@loadtest.example', 'Ravi Patel'),
  (5, 'emma@loadtest.example', 'Emma Novak')
) u (n, email, full_name);

insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
select id, id, id::text, 'email', jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true), now(), now(), now()
from auth.users where id in (select pg_temp.member(n) from generate_series(1, 5) n);

insert into public.profiles (user_id, full_name)
select id, raw_user_meta_data ->> 'full_name' from auth.users where id in (select pg_temp.member(n) from generate_series(1, 5) n);

insert into public.memberships (clinic_id, user_id, email, full_name, role, status, invited_by, invited_at)
select pg_temp.clinic(), u.id, u.email, u.raw_user_meta_data ->> 'full_name',
  case when u.id in (pg_temp.member(1), pg_temp.member(2)) then 'admin' else 'staff' end::public.membership_role,
  'active', case when u.id = pg_temp.member(1) then null else pg_temp.member(1) end, pg_temp.at(200, 540)
from auth.users u where u.id in (select pg_temp.member(n) from generate_series(1, 5) n);

-- Catalog --------------------------------------------------------------------------------------------------------------

insert into public.categories (clinic_id, name, position)
select pg_temp.clinic(), name, position
from unnest(array['Anesthetic', 'Restorative', 'Endodontics', 'Impression', 'Preventive', 'Surgical', 'PPE',
  'Sterilization', 'Disposable', 'Other']) with ordinality as c (name, position);

-- Ten of each kind: product n is kind (n - 1) / 10 + 1, variant (n - 1) % 10 + 1.
create temp table load_kinds (kind int primary key, category text, name text, unit text, pack_unit text, pack_size int,
  tracking text, variants text, cost numeric, supplier text);
insert into load_kinds values
  (1, 'Anesthetic', 'Articaine 4% 1:100,000', 'cartridges', 'box', 50, 'countable', 'make', 0.62, 'Patterson'),
  (2, 'Anesthetic', 'Lidocaine 2% 1:100,000', 'cartridges', 'box', 50, 'countable', 'make', 0.48, 'Patterson'),
  (3, 'Anesthetic', 'Mepivacaine 3%', 'cartridges', 'box', 50, 'countable', 'make', 0.55, 'Henry Schein'),
  (4, 'Anesthetic', 'Needle', 'needles', 'box', 100, 'countable', 'needle', 0.14, 'Patterson'),
  (5, 'Anesthetic', 'Topical anesthetic gel', 'jars', null, null, 'multi_use', 'flavour', 16.00, 'Henry Schein'),
  (6, 'Restorative', 'Composite', 'syringes', null, null, 'multi_use', 'shade', 38.00, 'Patterson'),
  (7, 'Restorative', 'Flowable composite', 'syringes', null, null, 'multi_use', 'shade', 29.00, 'Patterson'),
  (8, 'Restorative', 'Bonding agent', 'bottles', null, null, 'multi_use', 'make', 82.00, 'Patterson'),
  (9, 'Restorative', 'Etch gel 37%', 'syringes', null, null, 'multi_use', 'volume', 9.00, 'Benco'),
  (10, 'Restorative', 'Matrix band', 'bands', 'box', 12, 'countable', 'length', 0.80, 'Patterson'),
  (11, 'Restorative', 'Wedges', 'wedges', 'box', 100, 'countable', 'size', 0.09, 'Benco'),
  (12, 'Restorative', 'Glass ionomer', 'capsules', 'box', 50, 'countable', 'shade', 1.90, 'Henry Schein'),
  (13, 'Restorative', 'Temporary cement', 'kits', null, null, 'multi_use', 'make', 26.00, 'Patterson'),
  (14, 'Endodontics', 'K-file 25 mm', 'packs', null, null, 'countable', 'iso', 6.50, 'Henry Schein'),
  (15, 'Endodontics', 'Rotary file', 'packs', null, null, 'countable', 'iso', 24.00, 'Henry Schein'),
  (16, 'Endodontics', 'Gutta percha', 'packs', null, null, 'countable', 'iso', 6.50, 'Henry Schein'),
  (17, 'Endodontics', 'Paper points', 'packs', null, null, 'countable', 'iso', 5.50, 'Henry Schein'),
  (18, 'Endodontics', 'Sodium hypochlorite', 'bottles', null, null, 'multi_use', 'volume', 7.00, 'Benco'),
  (19, 'Endodontics', 'Root canal sealer', 'kits', null, null, 'multi_use', 'make', 64.00, 'Henry Schein'),
  (20, 'Endodontics', 'Rubber dam', 'sheets', 'box', 36, 'countable', 'size', 1.10, 'Henry Schein'),
  (21, 'Impression', 'Alginate impression', 'bags', null, null, 'multi_use', 'make', 14.00, 'Patterson'),
  (22, 'Impression', 'Impression material PVS', 'cartridges', null, null, 'multi_use', 'body', 21.00, 'Patterson'),
  (23, 'Impression', 'Impression tray', 'trays', 'box', 12, 'countable', 'size', 1.40, 'Benco'),
  (24, 'Impression', 'Bite registration', 'cartridges', null, null, 'multi_use', 'make', 18.00, 'Patterson'),
  (25, 'Impression', 'Mixing tips', 'tips', 'bag', 50, 'countable', 'size', 0.30, 'Benco'),
  (26, 'Preventive', 'Prophy paste', 'jars', null, null, 'multi_use', 'flavour', 18.00, 'Benco'),
  (27, 'Preventive', 'Prophy angle', 'angles', 'box', 100, 'countable', 'model', 0.45, 'Patterson'),
  (28, 'Preventive', 'Fluoride varnish', 'tubes', null, null, 'multi_use', 'flavour', 22.00, 'Henry Schein'),
  (29, 'Preventive', 'Sealant', 'syringes', null, null, 'multi_use', 'shade', 19.00, 'Henry Schein'),
  (30, 'Preventive', 'Floss', 'packs', 'box', 72, 'countable', 'model', 0.70, 'Benco'),
  (31, 'Surgical', 'Suture', 'packs', 'box', 12, 'countable', 'suture', 3.50, 'Henry Schein'),
  (32, 'Surgical', 'Gauze', 'packs', 'case', 20, 'countable', 'size', 3.20, 'Patterson'),
  (33, 'Surgical', 'Hemostatic gel', 'syringes', null, null, 'multi_use', 'make', 19.00, 'Benco'),
  (34, 'Surgical', 'Scalpel blade', 'blades', 'box', 100, 'countable', 'model', 0.35, 'Henry Schein'),
  (35, 'Surgical', 'Irrigation syringe', 'syringes', 'box', 50, 'countable', 'volume', 0.25, 'Benco'),
  (36, 'PPE', 'Nitrile gloves', 'pairs', 'box', 50, 'countable', 'size', 0.19, 'Benco'),
  (37, 'PPE', 'Face masks', 'masks', 'box', 50, 'countable', 'model', 0.14, 'Benco'),
  (38, 'PPE', 'Face shield', 'shields', 'box', 10, 'countable', 'model', 2.40, 'Benco'),
  (39, 'PPE', 'Isolation gown', 'gowns', 'case', 50, 'countable', 'size', 1.10, 'Benco'),
  (40, 'PPE', 'Safety glasses', 'pairs', null, null, 'countable', 'model', 4.00, 'Benco'),
  (41, 'Sterilization', 'Surface disinfectant', 'bottles', null, null, 'multi_use', 'volume', 12.00, 'Benco'),
  (42, 'Sterilization', 'Sterilization pouches', 'boxes', null, null, 'countable', 'pouch', 11.00, 'Benco'),
  (43, 'Sterilization', 'Indicator strips', 'packs', null, null, 'countable', 'model', 8.00, 'Benco'),
  (44, 'Sterilization', 'Instrument cleaner', 'bottles', null, null, 'multi_use', 'volume', 15.00, 'Benco'),
  (45, 'Sterilization', 'Disinfectant wipes', 'tubs', null, null, 'multi_use', 'make', 9.00, 'Benco'),
  (46, 'Disposable', 'Suction tips', 'tips', 'bag', 100, 'countable', 'model', 0.04, 'Benco'),
  (47, 'Disposable', 'Dental bib', 'bibs', 'case', 500, 'countable', 'model', 0.06, 'Benco'),
  (48, 'Disposable', 'Cotton rolls', 'rolls', 'box', 1000, 'countable', 'size', 0.02, 'Patterson'),
  (49, 'Other', 'Articulating paper', 'books', null, null, 'countable', 'model', 6.00, 'Patterson'),
  (50, 'Other', 'Polishing discs', 'discs', 'box', 50, 'countable', 'size', 0.90, 'Patterson');

create temp table load_variants (variants text, n int, label text, primary key (variants, n));
insert into load_variants
select v.variants, l.n, l.label
from (values
  ('make', array['Septodont', 'Dentsply', '3M', 'Kerr', 'GC', 'Ivoclar', 'Ultradent', 'Coltene', 'Voco', 'Shofu']),
  ('needle', array['25g long', '25g short', '27g long', '27g short', '27g extra long', '30g long', '30g short',
    '30g extra short', '31g short', '31g extra short']),
  ('flavour', array['mint', 'cherry', 'bubble gum', 'strawberry', 'unflavoured', 'mint fine', 'cherry fine',
    'mint coarse', 'cherry coarse', 'orange']),
  ('shade', array['A1', 'A2', 'A3', 'A3.5', 'A4', 'B1', 'B2', 'B3', 'C2', 'D3']),
  ('volume', array['1 ml', '2 ml', '3 ml', '5 ml', '10 ml', '30 ml', '100 ml', '250 ml', '500 ml', '1 l']),
  ('length', array['5 mm', '6 mm', '7 mm', '8 mm', '10 mm', '12 mm', '15 mm', '18 mm', '20 mm', '25 mm']),
  ('size', array['M', 'S', 'L', 'XS', 'XL', 'M latex-free', 'S latex-free', 'L latex-free', 'XS latex-free',
    'XL latex-free']),
  ('iso', array['#06', '#08', '#10', '#15', '#20', '#25', '#30', '#35', '#40', '#45']),
  ('body', array['light body', 'medium body', 'heavy body', 'putty', 'monophase', 'light body fast',
    'medium body fast', 'heavy body fast', 'putty fast', 'monophase fast']),
  ('model', array['standard', 'premium', 'small', 'large', 'soft', 'firm', 'blue', 'white', 'green', 'pink']),
  ('suture', array['2-0', '3-0', '4-0', '5-0', '6-0', '3-0 silk', '4-0 silk', '5-0 silk', '3-0 PGA', '4-0 PGA']),
  ('pouch', array['57 x 100 mm', '57 x 130 mm', '70 x 229 mm', '90 x 165 mm', '90 x 254 mm', '133 x 165 mm',
    '133 x 254 mm', '190 x 330 mm', '254 x 381 mm', '305 x 432 mm'])
) v (variants, labels)
cross join lateral unnest(v.labels) with ordinality as l (label, n);

-- Minimum and target in counted units: about half a pack to one and a half packs for the packed consumables, a few
-- for the rest, 0 to 2 unopened for multi-use ones (G3).
insert into public.products (id, clinic_id, name, category_id, unit, pack_unit, pack_size, minimum, target, supplier,
  location, tracking)
select pg_temp.pid(g.n), pg_temp.clinic(), k.name || ' ' || v.label,
  (select c.id from public.categories c where c.clinic_id = pg_temp.clinic() and c.name = k.category),
  k.unit, k.pack_unit, k.pack_size, m.minimum,
  case when k.tracking = 'multi_use' then m.minimum + pg_temp.pick('target:' || g.n, 2, 4) else m.minimum * 3 end,
  k.supplier,
  (array['Operatory 1 · Drawer A', 'Operatory 1 · Drawer B', 'Operatory 2 · Drawer A', 'Operatory 2 · Drawer B',
    'Operatory 3 · Cabinet', 'Hygiene · Drawer A', 'Sterilization · Shelf 1', 'Lab · Shelf 1'])[pg_temp.pick('location:' || g.n, 1, 8)],
  k.tracking::public.tracking_mode
from generate_series(1, 500) g (n)
join load_kinds k on k.kind = (g.n - 1) / 10 + 1
join load_variants v on v.variants = k.variants and v.n = (g.n - 1) % 10 + 1
cross join lateral (
  select case
    when k.tracking = 'multi_use' then pg_temp.pick('minimum:' || g.n, 0, 2)
    when k.pack_size is not null then greatest(round(k.pack_size * (0.5 + pg_temp.rnd('minimum:' || g.n))), 2)
    else pg_temp.pick('minimum:' || g.n, 2, 12)
  end::numeric as minimum
) m;

-- Gloves M, bibs, suction tips and cotton rolls, which every procedure uses.
create function pg_temp.core(i int) returns int language sql immutable as $$ select (array[351, 461, 451, 471])[i] $$;

-- Procedure templates, a minute apart (MS-122 lists them in creation order). Each lists the four consumables, in an
-- order of its own, among four to ten supplies of its own; countable defaults are 1 to 3 (cartridges and the like) or
-- 1, multi-use ones 0 (the open one is used).
insert into public.procedure_templates (id, clinic_id, name, created_at)
select pg_temp.tid(n::int), pg_temp.clinic(), name, pg_temp.at(190, 600) + make_interval(mins => n::int)
from unnest(array['Root canal', 'Cleaning', 'Filling', 'Crown preparation', 'Extraction', 'Scaling and root planing',
  'Sealants', 'Whitening', 'Veneer', 'Bridge', 'Denture adjustment', 'Endodontic retreatment', 'Pulpotomy',
  'Fluoride treatment', 'Exam', 'Impressions', 'Temporary crown', 'Post and core', 'Implant placement',
  'Night guard']) with ordinality as t (name, n);

insert into public.procedure_template_items (clinic_id, template_id, product_id, default_qty, position)
select distinct on (t, product) pg_temp.clinic(), pg_temp.tid(t), pg_temp.pid(product),
  case
    when p.tracking = 'multi_use' then 0
    when product = 351 then 2
    when product = 471 then 4
    when p.pack_size is not null and p.pack_size <= 100 then pg_temp.pick('qty:' || t || ':' || product, 1, 3)
    else 1
  end,
  position
from (
  -- The consumables at positions rotated by the template; the template's own supplies around them.
  select t, pg_temp.core(((i + t) % 4) + 1) as product, i * 3 as position
  from generate_series(1, 20) t, generate_series(0, 3) i
  union all
  select t, pg_temp.pick('item:' || t || ':' || i, 1, 500), i * 3 - 1
  from generate_series(1, 20) t, generate_series(1, 4 + t % 7) i
) items
join public.products p on p.id = pg_temp.pid(product)
order by t, product, position;

-- The story ---------------------------------------------------------------------------------------------------------------

-- A procedure started from a template as the app sends it: the countable supplies at their defaults (now and then one
-- more or one less), the multi-use ones at 0, and a new bottle taken for one in ten that has one unopened. Answers the
-- procedure's id.
create function pg_temp.procedure(p_step text, p_user uuid, p_template int, p_at timestamptz) returns uuid
language plpgsql as $$
declare
  v_items jsonb;
  v_take_new uuid[];
  v_id uuid;
begin
  perform pg_temp.act_as(p_user);
  select jsonb_agg(jsonb_build_object('product_id', i.product_id, 'qty',
      case
        when p.tracking = 'multi_use' then 0
        when pg_temp.rnd(p_step || ':more:' || i.product_id) < 0.1 then i.default_qty + 1
        when pg_temp.rnd(p_step || ':less:' || i.product_id) < 0.1 then greatest(i.default_qty - 1, 0)
        else i.default_qty
      end) order by p.tracking, i.position),
    coalesce(array_agg(i.product_id order by i.position) filter (
      where p.tracking = 'multi_use' and s.unopened >= 1 and pg_temp.rnd(p_step || ':new:' || i.product_id) < 0.1
    ), '{}')
  into v_items, v_take_new
  from public.procedure_template_items i
  join public.products p on p.id = i.product_id
  join public.product_stock s on s.product_id = i.product_id
  where i.template_id = pg_temp.tid(p_template);
  v_id := public.stock_procedure_start(pg_temp.clinic(), pg_temp.tid(p_template),
    (select name from public.procedure_templates where id = pg_temp.tid(p_template)), v_items, v_take_new,
    pg_temp.key(p_step));
  perform pg_temp.backdate(p_at);
  return v_id;
end;
$$;

-- Edit usage: one supply recorded one more or one less, the rest and the bottles taken new as they were.
create function pg_temp.edit(p_step text, p_user uuid, p_event uuid, p_at timestamptz) returns void language plpgsql as $$
declare
  v_changed uuid;
  v_items jsonb;
begin
  perform pg_temp.act_as(p_user);
  select i.product_id into v_changed
  from public.procedure_event_items i join public.products p on p.id = i.product_id
  where i.event_id = p_event and p.tracking = 'countable'
  order by md5(p_step || i.product_id::text) limit 1;
  select jsonb_agg(jsonb_build_object('product_id', i.product_id, 'qty',
      case when i.product_id = v_changed then
        case when pg_temp.rnd(p_step || ':up') < 0.5 then i.qty + 1 else greatest(i.qty - 1, 0) end
      else i.qty end) order by i.product_id)
  into v_items
  from public.procedure_event_items i where i.event_id = p_event;
  perform public.stock_procedure_edit(p_event, v_items,
    coalesce((select array_agg(o.product_id order by o.product_id) from public.procedure_event_openings o where o.event_id = p_event), '{}'),
    pg_temp.key(p_step));
  perform pg_temp.backdate(p_at);
end;
$$;

do $$
declare
  c uuid := pg_temp.clinic();
  v_day date;
  v_dow int;
  v_slot int;
  v_procedures int;
  v_user uuid;
  v_event uuid;
  v_product int;
  v_lines jsonb;
  v_id uuid;
  v_item record;
  v_counted int := -1;
begin
  -- 180 days ago at 8 am Olivia receives the opening stock, 50 lines at a time: about two packs or twice the target,
  -- lots and expiries on most batches (from 2 months past to 30 months ahead), undated stock on one product in seven, a
  -- second lot on one in seven.
  perform pg_temp.act_as(pg_temp.member(1));
  for v_slot in 0..9 loop
    select jsonb_agg(l.line order by l.n, l.k) into v_lines
    from (
      select n, k, jsonb_build_object(
        'product_id', pg_temp.pid(n),
        'qty', case
          when p.tracking = 'multi_use' then p.target + 1
          else p.target + round(p.target * pg_temp.rnd('open:qty:' || n || ':' || k))
        end,
        'unit_cost', round((kind.cost * (0.9 + 0.2 * pg_temp.rnd('open:cost:' || n)))::numeric, 4),
        'lot', case when pg_temp.rnd('open:undated:' || n) < 0.14 and k = 1 then null else 'L' || n || chr(64 + k) end,
        'expiry_month', case when pg_temp.rnd('open:undated:' || n) < 0.14 and k = 1 then null
          else pg_temp.expiry_in(pg_temp.pick('open:expiry:' || n || ':' || k, -60, 900)) end
      ) as line
      from generate_series(v_slot * 50 + 1, v_slot * 50 + 50) n
      cross join generate_series(1, 2) k
      join public.products p on p.id = pg_temp.pid(n)
      join load_kinds kind on kind.kind = (n - 1) / 10 + 1
      where k = 1 or pg_temp.rnd('open:second:' || n) < 0.14
    ) l;
    perform public.stock_receive(c, v_lines, pg_temp.key('open:' || v_slot), 'manual', null, 'Opening stock');
    perform pg_temp.backdate(pg_temp.at(180, 480 + v_slot));
  end loop;

  for v_days in reverse 179..1 loop
    v_day := pg_temp.today() - v_days;
    v_dow := extract(isodow from v_day);
    continue when v_dow >= 6;

    -- Monday 9 am: what was ordered arrives, at the quantity ordered, in a lot of the week's with an expiry 1 to 2.5
    -- years out (undated for the products whose opening stock was).
    if v_dow = 1 then
      perform pg_temp.act_as(pg_temp.member(1));
      select jsonb_agg(jsonb_build_object(
          'product_id', t.product_id, 'qty', t.qty,
          'unit_cost', round((kind.cost * (0.9 + 0.2 * pg_temp.rnd('in:cost:' || v_days || ':' || t.product_id)))::numeric, 4),
          'lot', case when pg_temp.rnd('open:undated:' || pg_temp.pnum(p.id)) >= 0.14 then 'W' || v_days end,
          'expiry_month', case when pg_temp.rnd('open:undated:' || pg_temp.pnum(p.id)) >= 0.14
            then pg_temp.expiry_in(pg_temp.pick('in:expiry:' || v_days || ':' || t.product_id, 360, 900) - v_days) end
        ) order by p.name)
      into v_lines
      from public.to_buy_items t
      join public.products p on p.id = t.product_id
      join load_kinds kind on kind.kind = (pg_temp.pnum(p.id) - 1) / 10 + 1
      where t.clinic_id = c and t.status = 'ordered';
      if v_lines is not null then
        perform public.stock_receive(c, v_lines, pg_temp.key('in:' || v_days), 'manual', null, 'Receive manually');
        perform pg_temp.backdate(pg_temp.at(v_days, 540));
      end if;
    end if;

    -- Three or four procedures, an hour and a half apart from 8:30; one in twelve is edited five minutes later and
    -- one in twenty-five cancelled ten minutes later.
    v_procedures := 3 + (pg_temp.rnd('day:' || v_days) < 0.5)::int;
    for v_slot in 1..v_procedures loop
      v_user := pg_temp.member(pg_temp.pick('who:' || v_days || ':' || v_slot, 1, 5));
      v_event := pg_temp.procedure('p:' || v_days || ':' || v_slot, v_user,
        pg_temp.pick('template:' || v_days || ':' || v_slot, 1, 20), pg_temp.at(v_days, 420 + v_slot * 90));
      if pg_temp.rnd('edit:' || v_days || ':' || v_slot) < 0.08 then
        perform pg_temp.edit('e:' || v_days || ':' || v_slot, v_user, v_event, pg_temp.at(v_days, 425 + v_slot * 90));
      elsif pg_temp.rnd('cancel:' || v_days || ':' || v_slot) < 0.04 then
        perform pg_temp.act_as(v_user);
        perform public.stock_procedure_cancel(v_event,
          (array['Started twice by mistake', 'Wrong procedure chosen', 'Not done today'])[pg_temp.pick('note:' || v_days, 1, 3)],
          pg_temp.key('c:' || v_days || ':' || v_slot));
        perform pg_temp.backdate(pg_temp.at(v_days, 430 + v_slot * 90));
      end if;
    end loop;

    -- At 9:15 and 2:15 someone opens a bottle of a multi-use product that has one unopened, and at 9:20 and 2:20 the
    -- oldest bottle open for over three days is finished.
    for v_slot in 1..2 loop
      perform pg_temp.act_as(pg_temp.member(pg_temp.pick('bottle:who:' || v_days || ':' || v_slot, 1, 5)));
      select s.product_id into v_id
      from public.product_stock s
      where s.clinic_id = c and s.tracking = 'multi_use' and s.unopened >= 1 and s.open_count < 2
      order by md5('bottle:' || v_days || ':' || v_slot || s.product_id::text) limit 1;
      if v_id is not null then
        perform public.bottle_open(v_id, pg_temp.key('open:' || v_days || ':' || v_slot));
        perform pg_temp.backdate(pg_temp.at(v_days, 255 + v_slot * 300));
      end if;
      select o.id into v_id
      from public.open_items o
      where o.clinic_id = c and o.finished_at is null and o.opened_at < pg_temp.at(v_days + 3, 0)
      order by o.opened_at, o.product_id limit 1;
      if v_id is not null then
        perform public.bottle_finish(v_id, pg_temp.key('finish:' || v_days || ':' || v_slot));
        perform pg_temp.backdate(pg_temp.at(v_days, 260 + v_slot * 300));
      end if;
    end loop;

    -- Two days in five, at 12:10, an admin writes one or two units off.
    if pg_temp.rnd('adjust:' || v_days) < 0.4 then
      perform pg_temp.act_as(pg_temp.member(2));
      v_product := pg_temp.pick('adjust:product:' || v_days, 1, 500);
      perform public.stock_adjust(pg_temp.pid(v_product),
        greatest((select s.unopened from public.product_stock s where s.product_id = pg_temp.pid(v_product))
          - pg_temp.pick('adjust:qty:' || v_days, 1, 2), 0),
        (array['Damaged', 'Missing', 'Waste', 'Expired'])[pg_temp.pick('adjust:reason:' || v_days, 1, 4)], null,
        pg_temp.key('adjust:' || v_days));
      perform pg_temp.backdate(pg_temp.at(v_days, 730));
    end if;

    -- Tuesday 11 am: a staff member adds a product to To buy.
    if v_dow = 2 then
      perform pg_temp.act_as(pg_temp.member(pg_temp.pick('add:who:' || v_days, 3, 5)));
      perform public.to_buy_add(c, pg_temp.pid(pg_temp.pick('add:product:' || v_days, 1, 500)));
      perform pg_temp.backdate(pg_temp.at(v_days, 660));
    end if;

    -- Wednesday 12:30: Olivia disposes of up to two batches that expired by then.
    if v_dow = 3 then
      perform pg_temp.act_as(pg_temp.member(1));
      for v_item in
        select b.id, b.qty from public.batches b
        where b.clinic_id = c and b.qty > 0 and b.expiry_month is not null
          and (b.expiry_month + interval '1 month' - interval '1 day')::date < v_day
        order by b.expiry_month, b.lot limit 2
      loop
        perform public.stock_dispose(v_item.id, v_item.qty, pg_temp.key('dispose:' || v_item.id));
        perform pg_temp.backdate(pg_temp.at(v_days, 750));
      end loop;
      -- At 4:30 pm she marks every line to buy as ordered; it arrives on Monday.
      perform public.to_buy_mark_ordered(c,
        (select array_agg(t.id) from public.to_buy_items t where t.clinic_id = c and t.status = 'to_buy'));
      perform pg_temp.backdate(pg_temp.at(v_days, 990));
    end if;

    -- Once a month, on the first working day of each 30 days, Marcus counts 80 products at 5 pm; about a third differ
    -- from the estimate by one to three.
    if v_days / 30 <> v_counted then
      v_counted := v_days / 30;
      perform pg_temp.act_as(pg_temp.member(2));
      select jsonb_agg(jsonb_build_object('product_id', s.product_id, 'counted', greatest(s.unopened
          + case when pg_temp.rnd('count:' || v_days || ':' || s.product_id) < 0.35
            then (array[-3, -2, -1, 1, 2, 3])[pg_temp.pick('count:by:' || v_days || ':' || s.product_id, 1, 6)] else 0 end,
          0)) order by s.product_id)
      into v_lines
      from public.product_stock s
      where s.clinic_id = c and pg_temp.pnum(s.product_id) % 6 = v_counted and pg_temp.pnum(s.product_id) <= 480;
      perform public.stock_count_apply(c, v_lines, pg_temp.key('count:' || v_days));
      perform pg_temp.backdate(pg_temp.at(v_days, 1020));
    end if;
  end loop;
end;
$$;

-- Receive delivery (MS-126, MS-129): an invoice read this morning and waiting for review, and one whose reading failed.
insert into public.invoices (id, clinic_id, storage_path, source, status, supplier, number, invoice_date, total, currency,
  created_by, created_at, file_kind, file_count, read_started_at, read_at, failure_reason)
values
  (pg_temp.invoice(1), pg_temp.clinic(), pg_temp.clinic() || '/' || pg_temp.invoice(1), 'camera', 'ready', 'Benco',
   'BN-55120', pg_temp.today() - 3, 183.40, 'CAD', pg_temp.member(1), pg_temp.at(1, 500), 'jpg', 1, pg_temp.at(1, 500),
   pg_temp.at(1, 500), null),
  (pg_temp.invoice(2), pg_temp.clinic(), pg_temp.clinic() || '/' || pg_temp.invoice(2), 'file', 'failed', null, null,
   null, null, null, pg_temp.member(1), pg_temp.at(1, 520), 'pdf', 1, pg_temp.at(1, 520), pg_temp.at(1, 521),
   'unreadable');
insert into public.invoice_lines (clinic_id, invoice_id, n, raw, qty, unit, unit_price, line_total, state, suggested_product_id,
  product_id, kind, suggested_name, suggested_unit, created_at)
values
  (pg_temp.clinic(), pg_temp.invoice(1), 1, 'NITRILE GLOVE MED 50/BX', 10, 'boxes', 9.50, 95.00, 'matched', null,
   pg_temp.pid(351), 'product', null, null, pg_temp.at(1, 500)),
  (pg_temp.clinic(), pg_temp.invoice(1), 2, 'SUCTION TIP WHITE 100/BG', 4, 'bags', 4.25, 17.00, 'possible_match',
   pg_temp.pid(451), null, 'product', null, null, pg_temp.at(1, 500)),
  (pg_temp.clinic(), pg_temp.invoice(1), 3, 'COTTON ROLL #2 MED 2000/BX', 2, 'boxes', 33.60, 67.20, 'new_product', null,
   null, 'product', 'Cotton roll #2 medium', 'boxes', pg_temp.at(1, 500)),
  (pg_temp.clinic(), pg_temp.invoice(1), 4, 'FREIGHT', 1, null, 4.20, 4.20, 'needs_review', null, null, 'fee',
   null, null, pg_temp.at(1, 500));
insert into public.alerts (clinic_id, kind, invoice_id, opened_at, created_at)
values (pg_temp.clinic(), 'invoice_ready', pg_temp.invoice(1), pg_temp.at(1, 501), pg_temp.at(1, 501));

alter table public.transactions enable trigger transactions_append_only;

-- Checks: the clinic's size, the ledger agrees with the stock, nothing in the future -------------------------------------

do $$
declare
  c uuid := pg_temp.clinic();
  v_ledger integer;
  v_wrong text;
begin
  if (select count(*) from public.products where clinic_id = c) <> 500 then
    raise exception 'The load clinic has % products, not 500', (select count(*) from public.products where clinic_id = c);
  end if;
  select count(*) into v_ledger from public.transactions where clinic_id = c;
  if v_ledger not between 4500 and 6000 then
    raise exception 'The load clinic''s ledger has % rows, not about 5,000', v_ledger;
  end if;

  -- Every product started at 0, so its ledger deltas add up to its stock.
  select string_agg(p.name, ', ') into v_wrong
  from public.products p
  join public.product_stock s on s.product_id = p.id
  where p.clinic_id = c
    and s.quantity <> (select coalesce(sum(t.delta), 0) from public.transactions t where t.product_id = p.id);
  if v_wrong is not null then
    raise exception 'The ledger does not end at the stock for: %', v_wrong;
  end if;
  if exists (select 1 from public.transactions where clinic_id = c and (at >= now() or created_at >= now()))
    or exists (select 1 from public.stock_actions where clinic_id = c and created_at >= now())
    or exists (select 1 from public.open_items where clinic_id = c and greatest(opened_at, finished_at) >= now())
    or exists (select 1 from public.procedure_events where clinic_id = c and greatest(started_at, cancelled_at) >= now())
    or exists (select 1 from public.to_buy_items where clinic_id = c and greatest(created_at, ordered_at, received_at) >= now())
    or exists (select 1 from public.alerts where clinic_id = c and greatest(opened_at, resolved_at) >= now())
  then
    raise exception 'A row of the load clinic is dated now or later';
  end if;

  raise notice 'Load test dental: % products, % batches, % ledger rows, % procedures, % To buy lines, % open alerts',
    (select count(*) from public.products where clinic_id = c),
    (select count(*) from public.batches where clinic_id = c),
    v_ledger,
    (select count(*) from public.procedure_events where clinic_id = c),
    (select count(*) from public.to_buy_items where clinic_id = c),
    (select count(*) from public.alerts where clinic_id = c and resolved_at is null);
end;
$$;

commit;
