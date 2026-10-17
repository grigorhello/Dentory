-- MS-109 · The demo clinic "Smile Dental" from the design (frames f6, f11, f16, f25, f27, f31; prototype
-- design/project/Dentory Mobile.dc.html: P, T, events, lines, orders, expiring).
--
-- Run after a reset: `make db-reset seed-demo`. Local stack only; never run it against a hosted project.
--
-- Stock moves only through the MS-106 RPC functions, called as the person the story says did it, so batches,
-- open items, the ledger, alerts and the To buy list are exactly what the engine writes. Dates are relative
-- to today in the clinic's time zone (the frames' "Thursday, October 2" is today, "Oct 1" is yesterday), so the
-- Home tiles match f6 on the day the seed runs: 3 To buy, 2 Expiring soon, 1 Missing expiry. Nothing moves the
-- dates afterwards, so the expiry figures drift as days pass: reseed before a demo or a screenshot session.
-- After each step the rows it wrote are moved back to the time the story gives it (see pg_temp.backdate); that
-- touches timestamps only, never a quantity, and the ledger's append-only trigger is switched back on at the end.
--
-- Where the prototype data breaks a PRD rule, the rule wins (MS-100 D2):
-- - Multi-use minimums count unopened only (G3). The prototype compares minimum with unopened + open, so each
--   multi-use minimum here is the prototype minimum minus its open count; every status in f16 stays the same.
-- - Bonding agent has 1 unopened bottle in lot BA7 besides the open one: an expiring batch needs stock in it
--   (f27 lists "1 bottle · lot BA7"), and the open bottle carries no batch.
-- - Septocaine lot A112 expires after the 90-day window; with both lots inside it f6 would read 3 Expiring soon.
--   Lot B441 is inside it (f27), so Septocaine's badge is Expiring, not the Healthy f16 draws.
-- - Root canal sealer and Temporary cement are Low (0 unopened, as f16 draws), so the engine puts them on To buy;
--   they are marked Ordered with the others on "Oct 1", so the To buy tab reads 3 as in f25 (Ordered reads 5, not 3).
-- - To buy quantities are in counted units (PRD §4: target − current), so Needle 27g short is 60, not "2".
-- - Composite A2's open syringe is the one the Filling took new (events e3, Sarah, 2 days ago); P lists Dr. Kim,
--   7 days ago. The prototype contradicts itself there, and the procedure history is what the frames show.
--
-- Sign in with sarah@smiledental.ca (Admin) or michael@smiledental.ca (Staff), password "smiledental".

begin;

do $$
begin
  if exists (select 1 from public.clinics where id = 'd0000000-0000-4000-8000-000000000001') then
    raise exception 'The demo clinic is already there. Run make db-reset first.';
  end if;
end;
$$;

-- Helpers ----------------------------------------------------------------------------------------------

create function pg_temp.clinic() returns uuid language sql immutable as $$ select 'd0000000-0000-4000-8000-000000000001'::uuid $$;
create function pg_temp.sarah() returns uuid language sql immutable as $$ select 'd0000000-0000-4000-8000-000000000101'::uuid $$;
create function pg_temp.daniel() returns uuid language sql immutable as $$ select 'd0000000-0000-4000-8000-000000000102'::uuid $$;
create function pg_temp.michael() returns uuid language sql immutable as $$ select 'd0000000-0000-4000-8000-000000000103'::uuid $$;
-- Products keep the prototype ids 1–20; 21–29 are the template products the prototype has no row for.
create function pg_temp.pid(n int) returns uuid language sql immutable as $$ select ('d0000000-0000-4000-8000-0000000002' || lpad(n::text, 2, '0'))::uuid $$;
create function pg_temp.tid(n int) returns uuid language sql immutable as $$ select ('d0000000-0000-4000-8000-0000000003' || lpad(n::text, 2, '0'))::uuid $$;
create function pg_temp.product(p_name text) returns uuid language sql stable as $$
  select id from public.products where clinic_id = pg_temp.clinic() and name = p_name
$$;

-- Today in the clinic's time zone.
create function pg_temp.today() returns date language sql stable as $$ select (now() at time zone 'America/Toronto')::date $$;
-- A moment N days ago at a clinic wall-clock time, never later than now (a run at 7 AM keeps "today 8:55 AM" in the past).
create function pg_temp.ago(p_days int, p_time time) returns timestamptz language sql stable as $$
  select least(now(), ((pg_temp.today() - p_days) + p_time) at time zone 'America/Toronto')
$$;
-- The expiry month that holds the day N days from today: its month end is N to N + 30 days away.
create function pg_temp.expiry_in(p_days int) returns date language sql stable as $$
  select date_trunc('month', pg_temp.today() + p_days)::date
$$;

-- Calls the next RPC as this person.
create function pg_temp.act_as(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true)
$$;

-- Every row the last step wrote still carries now() (the whole seed is one transaction); move them to p_at.
create function pg_temp.backdate(p_at timestamptz) returns void language plpgsql as $$
declare
  c uuid := pg_temp.clinic();
begin
  update public.transactions set at = p_at, created_at = p_at where clinic_id = c and created_at = now();
  update public.stock_actions set created_at = p_at where clinic_id = c and created_at = now();
  update public.batches set created_at = p_at where clinic_id = c and created_at = now();
  update public.open_items set opened_at = p_at, created_at = p_at where clinic_id = c and created_at = now();
  update public.procedure_events set started_at = p_at, created_at = p_at where clinic_id = c and created_at = now();
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

-- Clinic and people (f31) ------------------------------------------------------------------------------

insert into public.clinics (id, name, city, country, currency, time_zone)
values (pg_temp.clinic(), 'Smile Dental', 'Toronto', 'CA', 'CAD', 'America/Toronto');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', email,
  extensions.crypt('smiledental', extensions.gen_salt('bf')), now(),
  '{"provider": "email", "providers": ["email"]}', jsonb_build_object('full_name', full_name), now(), now(),
  '', '', '', ''
from (values
  (pg_temp.sarah(), 'sarah@smiledental.ca', 'Sarah Mitchell'),
  (pg_temp.daniel(), 'daniel@smiledental.ca', 'Dr. Daniel Kim'),
  (pg_temp.michael(), 'michael@smiledental.ca', 'Michael Reyes')
) u (id, email, full_name);

insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
select id, id, id::text, 'email', jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true), now(), now(), now()
from auth.users where id in (pg_temp.sarah(), pg_temp.daniel(), pg_temp.michael());

insert into public.profiles (user_id, full_name) values
  (pg_temp.sarah(), 'Sarah Mitchell'),
  (pg_temp.daniel(), 'Dr. Daniel Kim'),
  (pg_temp.michael(), 'Michael Reyes');

insert into public.memberships (clinic_id, user_id, email, full_name, role, status, invited_by, invited_at, invite_expires_at) values
  (pg_temp.clinic(), pg_temp.sarah(), 'sarah@smiledental.ca', 'Sarah Mitchell', 'admin', 'active', null, pg_temp.ago(90, '09:00'), null),
  (pg_temp.clinic(), pg_temp.daniel(), 'daniel@smiledental.ca', 'Dr. Daniel Kim', 'admin', 'active', pg_temp.sarah(), pg_temp.ago(90, '09:30'), null),
  (pg_temp.clinic(), pg_temp.michael(), 'michael@smiledental.ca', 'Michael Reyes', 'staff', 'active', pg_temp.sarah(), pg_temp.ago(90, '09:30'), null),
  -- Invited "Oct 1"; the link is valid for 7 days (MS-100 G4). No token: the demo invitation is never accepted.
  (pg_temp.clinic(), null, 'priya@smiledental.ca', '', 'staff', 'invited', pg_temp.sarah(), pg_temp.ago(1, '10:00'), pg_temp.ago(1, '10:00') + interval '7 days');

-- Catalog (MS-100 D13 categories; prototype P plus the template products it lacks) ---------------------

insert into public.categories (clinic_id, name, position)
select pg_temp.clinic(), name, position
from unnest(array['Anesthetic', 'Restorative', 'Endodontics', 'Impression', 'Preventive', 'Surgical', 'PPE',
  'Sterilization', 'Disposable', 'Other']) with ordinality as c (name, position);

-- Prototype mode: Unit → countable, Package → countable with a pack, Container → multi_use.
insert into public.products (id, clinic_id, name, category_id, unit, pack_unit, pack_size, minimum, target, supplier, location, tracking)
select pg_temp.pid(n), pg_temp.clinic(), name,
  (select id from public.categories where clinic_id = pg_temp.clinic() and categories.name = category),
  unit, pack_unit, pack_size, minimum, target, supplier, location, tracking::public.tracking_mode
from (values
  (1, 'Septocaine 4% 1:100,000', 'Anesthetic', 'cartridges', 'box', 50, 20, 60, 'Patterson', 'Operatory 1 · Drawer A', 'countable'),
  (2, 'Endo file kit #15-40', 'Endodontics', 'kits', null, null, 3, 5, 'Patterson', 'Operatory 2 · Drawer B', 'countable'),
  (3, 'Composite A2', 'Restorative', 'syringes', null, null, 2, 6, 'Patterson', 'Operatory 1 · Drawer C', 'multi_use'),
  (4, 'Bonding agent', 'Restorative', 'bottles', null, null, 0, 2, 'Patterson', 'Operatory 1 · Drawer C', 'multi_use'),
  (5, 'Nitrile gloves M', 'PPE', 'boxes', 'case', 10, 6, 20, 'Benco', 'Sterilization · Shelf 2', 'countable'),
  (6, 'Surface disinfectant', 'Sterilization', 'bottles', null, null, 0, 4, 'Benco', 'Sterilization · Cabinet', 'multi_use'),
  (7, 'Rubber dam latex-free', 'Endodontics', 'sheets', null, null, 10, 36, 'Henry Schein', 'Operatory 2 · Drawer A', 'countable'),
  (8, 'Gutta percha F2', 'Endodontics', 'packs', null, null, 3, 10, 'Henry Schein', 'Operatory 2 · Drawer B', 'countable'),
  (9, 'Suction tips', 'Disposable', 'bags', 'case', 4, 4, 12, 'Benco', 'Sterilization · Shelf 1', 'countable'),
  (10, 'Alginate impression', 'Impression', 'bags', null, null, 1, 6, 'Patterson', 'Lab · Shelf 1', 'multi_use'),
  (11, 'Composite A3', 'Restorative', 'syringes', null, null, 1, 5, 'Patterson', 'Operatory 1 · Drawer C', 'multi_use'),
  (12, 'Etch gel 37%', 'Restorative', 'syringes', null, null, 0, 3, 'Patterson', 'Operatory 1 · Drawer C', 'multi_use'),
  (13, 'Topical anesthetic gel', 'Anesthetic', 'jars', null, null, 0, 3, 'Henry Schein', 'Operatory 1 · Drawer A', 'multi_use'),
  (14, 'Fluoride varnish', 'Preventive', 'tubes', null, null, 0, 4, 'Henry Schein', 'Hygiene · Drawer B', 'multi_use'),
  (15, 'Prophy paste jar', 'Preventive', 'jars', null, null, 0, 3, 'Benco', 'Hygiene · Drawer B', 'multi_use'),
  (16, 'Sodium hypochlorite', 'Endodontics', 'bottles', null, null, 0, 3, 'Henry Schein', 'Operatory 2 · Drawer B', 'multi_use'),
  (17, 'Root canal sealer', 'Endodontics', 'kits', null, null, 0, 2, 'Henry Schein', 'Operatory 2 · Drawer B', 'multi_use'),
  (18, 'Impression material PVS', 'Impression', 'cartridges', null, null, 1, 8, 'Patterson', 'Lab · Shelf 1', 'multi_use'),
  (19, 'Temporary cement', 'Restorative', 'kits', null, null, 0, 2, 'Patterson', 'Lab · Shelf 1', 'multi_use'),
  (20, 'Hemostatic gel', 'Surgical', 'syringes', null, null, 1, 3, 'Benco', 'Operatory 2 · Drawer A', 'multi_use'),
  (21, 'Needle 27g short', 'Anesthetic', 'needles', 'box', 100, 20, 100, 'Patterson', 'Operatory 1 · Drawer A', 'countable'),
  (22, 'Paper points', 'Endodontics', 'packs', null, null, 2, 8, 'Henry Schein', 'Operatory 2 · Drawer B', 'countable'),
  (23, 'Prophy angle', 'Preventive', 'angles', 'box', 100, 20, 100, 'Patterson', 'Hygiene · Drawer A', 'countable'),
  (24, 'Patient bib', 'Disposable', 'bibs', 'case', 500, 50, 500, 'Benco', 'Sterilization · Shelf 1', 'countable'),
  (25, 'Matrix band', 'Restorative', 'bands', null, null, 10, 50, 'Patterson', 'Operatory 1 · Drawer B', 'countable'),
  (26, 'Microbrushes', 'Restorative', 'brushes', 'box', 100, 25, 100, 'Benco', 'Operatory 1 · Drawer B', 'countable'),
  (27, 'Retraction cord', 'Restorative', 'packs', null, null, 1, 4, 'Henry Schein', 'Operatory 1 · Drawer B', 'countable'),
  (28, 'Gauze', 'Surgical', 'packs', null, null, 4, 10, 'Patterson', 'Operatory 2 · Drawer A', 'countable'),
  (29, 'Suture', 'Surgical', 'packs', null, null, 1, 6, 'Henry Schein', 'Operatory 2 · Drawer A', 'countable')
) p (n, name, category, unit, pack_unit, pack_size, minimum, target, supplier, location, tracking);

-- Procedure templates (prototype T, f11). Multi-use products default to 0: the open one is used.
insert into public.procedure_templates (id, clinic_id, name, created_at)
select pg_temp.tid(n), pg_temp.clinic(), name, pg_temp.ago(80, '12:00')
from (values (1, 'Root canal'), (2, 'Cleaning'), (3, 'Filling'), (4, 'Crown'), (5, 'Extraction')) t (n, name);

insert into public.procedure_template_items (clinic_id, template_id, product_id, default_qty, position)
select pg_temp.clinic(), pg_temp.tid(t), pg_temp.product(name), qty, position
from (values
  (1, 1, 'Septocaine 4% 1:100,000', 2), (1, 2, 'Needle 27g short', 1), (1, 3, 'Nitrile gloves M', 2),
  (1, 4, 'Rubber dam latex-free', 1), (1, 5, 'Endo file kit #15-40', 1), (1, 6, 'Gutta percha F2', 1),
  (1, 7, 'Paper points', 1), (1, 8, 'Suction tips', 1), (1, 9, 'Topical anesthetic gel', 0),
  (1, 10, 'Sodium hypochlorite', 0), (1, 11, 'Root canal sealer', 0), (1, 12, 'Surface disinfectant', 0),
  (2, 1, 'Prophy angle', 1), (2, 2, 'Nitrile gloves M', 2), (2, 3, 'Suction tips', 1), (2, 4, 'Patient bib', 1),
  (2, 5, 'Prophy paste jar', 0), (2, 6, 'Fluoride varnish', 0), (2, 7, 'Surface disinfectant', 0),
  (3, 1, 'Septocaine 4% 1:100,000', 1), (3, 2, 'Needle 27g short', 1), (3, 3, 'Nitrile gloves M', 2),
  (3, 4, 'Suction tips', 1), (3, 5, 'Matrix band', 1), (3, 6, 'Microbrushes', 2), (3, 7, 'Topical anesthetic gel', 0),
  (3, 8, 'Etch gel 37%', 0), (3, 9, 'Bonding agent', 0), (3, 10, 'Composite A2', 0), (3, 11, 'Composite A3', 0),
  (3, 12, 'Surface disinfectant', 0),
  (4, 1, 'Septocaine 4% 1:100,000', 2), (4, 2, 'Needle 27g short', 1), (4, 3, 'Nitrile gloves M', 2),
  (4, 4, 'Suction tips', 1), (4, 5, 'Retraction cord', 1), (4, 6, 'Topical anesthetic gel', 0),
  (4, 7, 'Impression material PVS', 0), (4, 8, 'Alginate impression', 0), (4, 9, 'Temporary cement', 0),
  (4, 10, 'Surface disinfectant', 0),
  (5, 1, 'Septocaine 4% 1:100,000', 2), (5, 2, 'Needle 27g short', 1), (5, 3, 'Nitrile gloves M', 2), (5, 4, 'Gauze', 4),
  (5, 5, 'Suture', 1), (5, 6, 'Topical anesthetic gel', 0), (5, 7, 'Hemostatic gel', 0), (5, 8, 'Surface disinfectant', 0)
) i (t, position, name, qty);

-- The story, oldest first -------------------------------------------------------------------------------

-- 75 days ago: Sarah receives the opening stock. Quantities are today's figures plus what the story uses
-- later. Lots and expiries follow the prototype; products it lists without a lot get a dated batch with no
-- lot, except Gutta percha F2, the one Missing expiry product. Unit costs put f27 at $82 + $104 = $186.
select pg_temp.act_as(pg_temp.sarah());
select public.stock_receive(pg_temp.clinic(), jsonb_agg(jsonb_build_object(
    'product_id', pg_temp.pid(n), 'qty', qty, 'unit_cost', unit_cost, 'lot', lot,
    'expiry_month', case when expiry_days is null then null else pg_temp.expiry_in(expiry_days) end
  ) order by n, expiry_days),
  gen_random_uuid(), 'manual', null, 'Opening stock')
from (values
  (1, 37, 3.06, 'B441', 60), (1, 20, 3.06, 'A112', 150), (2, 2, 45.00, null, 400), (3, 3, 38.00, 'C09', 530),
  (4, 2, 82.00, 'BA7', 32), (5, 20, 9.50, null, 700), (6, 3, 12.00, null, 600), (7, 1, 1.10, null, 600),
  (8, 8, 6.50, null, null), (9, 12, 4.25, null, 700), (10, 2, 14.00, 'AL3', 680), (11, 3, 38.00, 'C11', 500),
  (12, 2, 9.00, null, 450), (13, 2, 16.00, 'TG2', 590), (14, 3, 22.00, 'FV8', 470), (15, 2, 18.00, null, 500),
  (16, 2, 7.00, null, 500), (17, 1, 64.00, 'RS4', 560), (18, 6, 21.00, 'PV1', 710), (19, 1, 26.00, null, 500),
  (20, 2, 19.00, 'HG3', 740), (21, 42, 0.14, null, 900), (22, 6, 5.50, null, 800), (23, 31, 0.45, null, 900),
  (24, 181, 0.06, null, 900), (25, 36, 0.80, null, 900), (26, 82, 0.07, null, 900), (27, 3, 18.00, null, 700),
  (28, 8, 3.20, null, 900), (29, 4, 42.00, null, 600)
) l (n, qty, unit_cost, lot, expiry_days);
select pg_temp.backdate(pg_temp.ago(75, '09:00'));

-- Open bottles, syringes and kits as the prototype lists them (who, how many days ago). Alginate and the
-- second Surface disinfectant come later in the story.
create function pg_temp.open_bottle(p_user uuid, p_product int, p_days int, p_time time) returns void language sql as $$
  select pg_temp.act_as(p_user);
  select public.bottle_open(pg_temp.pid(p_product), gen_random_uuid());
  select pg_temp.backdate(pg_temp.ago(p_days, p_time));
$$;
select pg_temp.open_bottle(pg_temp.daniel(), 17, 60, '10:15');  -- Root canal sealer
select pg_temp.open_bottle(pg_temp.sarah(), 19, 45, '13:40');   -- Temporary cement
select pg_temp.open_bottle(pg_temp.sarah(), 12, 30, '09:20');   -- Etch gel 37%
select pg_temp.open_bottle(pg_temp.michael(), 6, 24, '08:10');  -- Surface disinfectant
select pg_temp.open_bottle(pg_temp.michael(), 15, 20, '08:30'); -- Prophy paste jar
select pg_temp.open_bottle(pg_temp.michael(), 13, 16, '11:05'); -- Topical anesthetic gel
select pg_temp.open_bottle(pg_temp.daniel(), 16, 14, '14:20');  -- Sodium hypochlorite
select pg_temp.open_bottle(pg_temp.daniel(), 11, 12, '10:45');  -- Composite A3

-- 10 days ago Michael puts Alginate impression on To buy by hand; Sarah marks it ordered the next day.
insert into public.to_buy_items (clinic_id, product_id, qty, qty_edited, source, added_by)
values (pg_temp.clinic(), pg_temp.pid(10), 2, true, 'manual', pg_temp.michael());
select pg_temp.backdate(pg_temp.ago(10, '16:30'));
update public.to_buy_items set status = 'ordered', ordered_at = now(), ordered_by = pg_temp.sarah()
where product_id = pg_temp.pid(10) and status = 'to_buy';
select pg_temp.backdate(pg_temp.ago(9, '09:10'));

select pg_temp.open_bottle(pg_temp.michael(), 14, 9, '13:30');  -- Fluoride varnish
select pg_temp.open_bottle(pg_temp.daniel(), 4, 8, '10:05');    -- Bonding agent

-- 6 days ago ("Sep 26") the Alginate arrives: Received in f25.
select pg_temp.act_as(pg_temp.sarah());
select public.stock_receive(pg_temp.clinic(),
  jsonb_build_array(jsonb_build_object('product_id', pg_temp.pid(10), 'qty', 2, 'unit_cost', 14.00, 'lot', 'AL3',
    'expiry_month', pg_temp.expiry_in(680))),
  gen_random_uuid(), 'manual', null, 'Receive manually');
select pg_temp.backdate(pg_temp.ago(6, '11:40'));

select pg_temp.open_bottle(pg_temp.michael(), 10, 5, '09:15');  -- Alginate impression
select pg_temp.open_bottle(pg_temp.daniel(), 18, 4, '15:50');   -- Impression material PVS
select pg_temp.open_bottle(pg_temp.sarah(), 6, 3, '08:05');     -- Surface disinfectant, the second one

-- 2 days ago ("Sep 30"): one Composite A2 syringe is damaged, then the Filling opens a new one.
select pg_temp.act_as(pg_temp.sarah());
select public.stock_adjust(pg_temp.pid(3), 2, 'Damaged', null, gen_random_uuid());
select pg_temp.backdate(pg_temp.ago(2, '14:02'));

-- The three past procedures (prototype events, f11 history), each with its template's default quantities.
create function pg_temp.procedure(p_user uuid, p_template int, p_take_new int[], p_days int, p_time time) returns void language sql as $$
  select pg_temp.act_as(p_user);
  select public.stock_procedure_start(
    pg_temp.clinic(), pg_temp.tid(p_template),
    (select name from public.procedure_templates where id = pg_temp.tid(p_template)),
    (select jsonb_agg(jsonb_build_object('product_id', product_id, 'qty', default_qty) order by position)
       from public.procedure_template_items where template_id = pg_temp.tid(p_template)),
    (select coalesce(array_agg(pg_temp.pid(n)), '{}') from unnest(p_take_new) n),
    gen_random_uuid());
  select pg_temp.backdate(pg_temp.ago(p_days, p_time));
$$;
select pg_temp.procedure(pg_temp.sarah(), 3, array[3], 2, '14:05');  -- Filling, Composite A2 taken new
select pg_temp.procedure(pg_temp.michael(), 2, '{}', 1, '11:20');    -- Cleaning
select pg_temp.procedure(pg_temp.sarah(), 1, '{}', 1, '15:14');      -- Root canal: Rubber dam runs out

-- Yesterday ("Oct 1") Sarah adds the prototype's ordered items by hand (Needle 27g short and Prophy angle at the
-- suggested quantity, 5 Gauze as in orders) and orders everything except the three lines f25 shows under To buy.
insert into public.to_buy_items (clinic_id, product_id, qty, qty_edited, source, added_by)
select pg_temp.clinic(), p.id,
  case when p.id = pg_temp.pid(28) then 5 else greatest(p.target - s.quantity, 1) end,
  p.id = pg_temp.pid(28), 'manual', pg_temp.sarah()
from public.products p join public.product_stock s on s.product_id = p.id
where p.id in (pg_temp.pid(21), pg_temp.pid(23), pg_temp.pid(28));
select pg_temp.backdate(pg_temp.ago(1, '16:35'));
update public.to_buy_items set status = 'ordered', ordered_at = now(), ordered_by = pg_temp.sarah()
where clinic_id = pg_temp.clinic() and status = 'to_buy'
  and product_id not in (pg_temp.pid(2), pg_temp.pid(3), pg_temp.pid(7));
select pg_temp.backdate(pg_temp.ago(1, '16:40'));

-- Today 8:55 AM: Patterson invoice INV-10092 has been read and waits for review (prototype lines, f23).
-- No file is uploaded to Storage; the path is where MS-129 would put it.
insert into public.invoices (id, clinic_id, storage_path, source, status, supplier, number, invoice_date, total, currency, created_by, created_at)
values ('d0000000-0000-4000-8000-000000000401', pg_temp.clinic(),
  pg_temp.clinic() || '/invoices/d0000000-0000-4000-8000-000000000401.jpg', 'camera', 'ready',
  'Patterson', 'INV-10092', pg_temp.today() - 2, 449.00, 'CAD', pg_temp.sarah(), pg_temp.ago(0, '08:55'));
insert into public.invoice_lines (clinic_id, invoice_id, n, raw, qty, unit, unit_price, line_total, state, suggested_product_id, product_id, created_at)
values
  (pg_temp.clinic(), 'd0000000-0000-4000-8000-000000000401', 1, 'SEPTO 4% 1:100K 50/BX', 5, 'boxes', 49.80, 249.00, 'matched', null, pg_temp.pid(1), pg_temp.ago(0, '08:55')),
  (pg_temp.clinic(), 'd0000000-0000-4000-8000-000000000401', 2, 'ENDO FILE KIT 15-40 21MM', 4, 'boxes', 45.00, 180.00, 'possible_match', pg_temp.pid(2), null, pg_temp.ago(0, '08:55')),
  (pg_temp.clinic(), 'd0000000-0000-4000-8000-000000000401', 3, 'TEMPBOND NE 1PK', 1, 'pack', 26.40, 26.40, 'new_product', null, null, pg_temp.ago(0, '08:55')),
  (pg_temp.clinic(), 'd0000000-0000-4000-8000-000000000401', 4, 'HANDLING / FUEL SURCHARGE', 1, null, 4.80, 4.80, 'needs_review', null, null, pg_temp.ago(0, '08:55'));
insert into public.alerts (clinic_id, kind, invoice_id, opened_at, created_at)
values (pg_temp.clinic(), 'invoice_ready', 'd0000000-0000-4000-8000-000000000401', pg_temp.ago(0, '08:56'), pg_temp.ago(0, '08:56'));

-- An expiring alert opens on the day its batch crosses the threshold (the daily refresh, 07:00 UTC), not on the
-- day the batch was received.
update public.alerts a
set opened_at = x.crossed, created_at = x.crossed
from (
  select a2.id, least(now(), ((((b.expiry_month + interval '1 month' - interval '1 day')::date - a2.threshold_days)
    + time '07:00') at time zone 'UTC')) as crossed
  from public.alerts a2 join public.batches b on b.id = a2.batch_id
  where a2.clinic_id = pg_temp.clinic() and a2.kind = 'expiring'
) x
where a.id = x.id and x.crossed > a.opened_at;

alter table public.transactions enable trigger transactions_append_only;

-- Checks: the frames' numbers, and the ledger agrees with the stock --------------------------------------

do $$
declare
  v_attention public.clinic_attention;
  v_wrong text;
begin
  select * into v_attention from public.clinic_attention where clinic_id = pg_temp.clinic();
  if (v_attention.to_buy_count, v_attention.expiring_batch_count, v_attention.missing_expiry_product_count) <> (3, 2, 1) then
    raise exception 'Home tiles read % To buy, % Expiring soon, % Missing expiry; f6 shows 3, 2, 1',
      v_attention.to_buy_count, v_attention.expiring_batch_count, v_attention.missing_expiry_product_count;
  end if;
  if v_attention.value_at_risk_90 <> 186.04 then
    raise exception 'At risk, 90 days is %; f6 shows $186', v_attention.value_at_risk_90;
  end if;

  -- f16 rows: quantity (multi-use: unopened + open), open count and status badge.
  select string_agg(format('%s: %s/%s/%s', p.name, ps.quantity, ps.open_count, ps.status), '; ') into v_wrong
  from (values
    (1, 54, 0, 'expiring'), (2, 1, 0, 'low'), (3, 2, 1, 'low'), (4, 2, 1, 'expiring'), (5, 14, 0, 'healthy'),
    (6, 3, 2, 'healthy'), (7, 0, 0, 'out_of_stock'), (8, 7, 0, 'missing_expiry'), (9, 9, 0, 'healthy'),
    (10, 4, 1, 'healthy'), (11, 3, 1, 'healthy'), (12, 2, 1, 'healthy'), (13, 2, 1, 'healthy'), (14, 3, 1, 'healthy'),
    (15, 2, 1, 'healthy'), (16, 2, 1, 'healthy'), (17, 1, 1, 'low'), (18, 6, 1, 'healthy'), (19, 1, 1, 'low'),
    (20, 2, 0, 'healthy'), (21, 40, 0, 'healthy'), (22, 5, 0, 'healthy'), (23, 30, 0, 'healthy'), (24, 180, 0, 'healthy'),
    (25, 35, 0, 'healthy'), (26, 80, 0, 'healthy'), (27, 3, 0, 'healthy'), (28, 8, 0, 'healthy'), (29, 4, 0, 'healthy')
  ) e (n, quantity, open_count, status)
  join public.product_status ps on ps.product_id = pg_temp.pid(e.n)
  join public.products p on p.id = ps.product_id
  where (ps.quantity, ps.open_count, ps.status) <> (e.quantity::numeric, e.open_count, e.status);
  if v_wrong is not null then
    raise exception 'Products differ from f16 (name: quantity/open/status): %', v_wrong;
  end if;

  -- f25: To buy 3 (Endo 4, Composite A2 4, Rubber dam 36), Ordered 5, Received 1.
  select string_agg(format('%s %s %s', p.name, t.status, t.qty), '; ') into v_wrong
  from public.to_buy_items t join public.products p on p.id = t.product_id
  where t.clinic_id = pg_temp.clinic()
    and (t.product_id, t.status::text, t.qty) not in (
      (pg_temp.pid(2), 'to_buy', 4), (pg_temp.pid(3), 'to_buy', 4), (pg_temp.pid(7), 'to_buy', 36),
      (pg_temp.pid(17), 'ordered', 1), (pg_temp.pid(19), 'ordered', 1), (pg_temp.pid(28), 'ordered', 5),
      (pg_temp.pid(21), 'ordered', 60), (pg_temp.pid(23), 'ordered', 70), (pg_temp.pid(10), 'received', 2));
  if v_wrong is not null or (select count(*) from public.to_buy_items where clinic_id = pg_temp.clinic()) <> 9 then
    raise exception 'To buy differs from f25: %', coalesce(v_wrong, 'wrong number of lines');
  end if;

  -- Every product started at 0, so its ledger deltas add up to its stock.
  select string_agg(p.name, ', ') into v_wrong
  from public.products p
  join public.product_stock s on s.product_id = p.id
  where p.clinic_id = pg_temp.clinic()
    and s.quantity <> (select coalesce(sum(t.delta), 0) from public.transactions t where t.product_id = p.id);
  if v_wrong is not null then
    raise exception 'The ledger does not end at the stock for: %', v_wrong;
  end if;
  if exists (select 1 from public.transactions where clinic_id = pg_temp.clinic() and at >= now()) then
    raise exception 'A ledger row was not moved back to its time in the story';
  end if;
  -- Nothing the story wrote is dated after the moment the seed ran.
  if exists (select 1 from public.stock_actions where clinic_id = pg_temp.clinic() and created_at > now())
    or exists (select 1 from public.open_items where clinic_id = pg_temp.clinic() and opened_at > now())
    or exists (select 1 from public.procedure_events where clinic_id = pg_temp.clinic() and started_at > now())
    or exists (select 1 from public.to_buy_items where clinic_id = pg_temp.clinic()
      and greatest(created_at, ordered_at, received_at) > now())
    or exists (select 1 from public.alerts where clinic_id = pg_temp.clinic() and greatest(opened_at, resolved_at) > now())
    or exists (select 1 from public.invoices where clinic_id = pg_temp.clinic() and created_at > now())
    or exists (select 1 from public.invoice_lines where clinic_id = pg_temp.clinic() and created_at > now())
    or exists (select 1 from public.memberships where clinic_id = pg_temp.clinic() and invited_at > now())
  then
    raise exception 'A row is dated in the future';
  end if;
end;
$$;

commit;
