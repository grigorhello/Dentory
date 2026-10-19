-- MS-122 · procedure_templates_list and procedure_history: what the Procedures tab reads, clinic-isolated.
begin;
select plan(18);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000000e31', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000000e32', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000000e33', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test'),
  ('00000000-0000-4000-8000-000000000e34', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'gone@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone, expiry_thresholds) values
  ('00000000-0000-4000-8000-000000000e41', 'Smile Dental', 'CA', 'CAD', 'America/Toronto', '{90}'),
  ('00000000-0000-4000-8000-000000000e42', 'Other Dental', 'CA', 'CAD', 'America/Toronto', '{90}');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e31', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e32', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000000e42', '00000000-0000-4000-8000-000000000e33', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
-- Septocaine 3 cartridges, Rubber dam 0, Gloves 2 boxes, Bonding agent 1 unopened (multi-use), Old gauze archived.
insert into public.products (id, clinic_id, name, unit, tracking, minimum, target, archived_at) values
  ('00000000-0000-4000-8000-000000000e61', '00000000-0000-4000-8000-000000000e41', 'Septocaine', 'cartridges', 'countable', 1, 5, null),
  ('00000000-0000-4000-8000-000000000e62', '00000000-0000-4000-8000-000000000e41', 'Rubber dam', 'sheets', 'countable', 1, 5, null),
  ('00000000-0000-4000-8000-000000000e63', '00000000-0000-4000-8000-000000000e41', 'Gloves', 'boxes', 'countable', 1, 5, null),
  ('00000000-0000-4000-8000-000000000e64', '00000000-0000-4000-8000-000000000e41', 'Bonding agent', 'bottles', 'multi_use', 0, 2, null),
  ('00000000-0000-4000-8000-000000000e65', '00000000-0000-4000-8000-000000000e41', 'Old gauze', 'packs', 'countable', 0, 2, now());
insert into public.batches (clinic_id, product_id, expiry_month, qty) values
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e61', null, 3),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e63', null, 2),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e64', null, 1),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e65', null, 9);
-- Root canal: 2 Septocaine, 1 Rubber dam (none left), 2 Gloves (exactly what is left), Bonding agent from the
-- open bottle, Old gauze (archived). Crown: 1 Septocaine and 1 Bonding agent taken new. Filling has no items.
-- Created in the order Root canal, Crown, Filling; Retired is archived.
insert into public.procedure_templates (id, clinic_id, name, created_at, archived_at) values
  ('00000000-0000-4000-8000-000000000e71', '00000000-0000-4000-8000-000000000e41', 'Root canal', now() - interval '3 days', null),
  ('00000000-0000-4000-8000-000000000e72', '00000000-0000-4000-8000-000000000e41', 'Crown', now() - interval '2 days', null),
  ('00000000-0000-4000-8000-000000000e73', '00000000-0000-4000-8000-000000000e41', 'Filling', now() - interval '1 day', null),
  ('00000000-0000-4000-8000-000000000e74', '00000000-0000-4000-8000-000000000e41', 'Retired', now() - interval '4 days', now()),
  ('00000000-0000-4000-8000-000000000e75', '00000000-0000-4000-8000-000000000e42', 'Other clinic template', now(), null);
insert into public.procedure_template_items (clinic_id, template_id, product_id, default_qty, position) values
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e71', '00000000-0000-4000-8000-000000000e61', 2, 1),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e71', '00000000-0000-4000-8000-000000000e62', 1, 2),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e71', '00000000-0000-4000-8000-000000000e63', 2, 3),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e71', '00000000-0000-4000-8000-000000000e64', 0, 4),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e71', '00000000-0000-4000-8000-000000000e65', 1, 5),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e72', '00000000-0000-4000-8000-000000000e61', 1, 1),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e72', '00000000-0000-4000-8000-000000000e64', 1, 2);
-- History: a Filling yesterday by Sarah, a cancelled Crown this morning by Michael, two Extractions by Sarah
-- within the same second three hours ago (the second one a few hundred milliseconds earlier), a Root canal an
-- hour ago by someone who has left the clinic, and another clinic's procedure.
insert into public.procedure_events (id, clinic_id, template_id, name, started_by, started_at, cancelled_at, cancelled_by, cancel_note) values
  ('00000000-0000-4000-8000-000000000e81', '00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e73', 'Filling', '00000000-0000-4000-8000-000000000e31', now() - interval '1 day', null, null, null),
  ('00000000-0000-4000-8000-000000000e82', '00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e72', 'Crown', '00000000-0000-4000-8000-000000000e32', now() - interval '5 hours', now() - interval '4 hours', '00000000-0000-4000-8000-000000000e32', 'Logged by mistake'),
  ('00000000-0000-4000-8000-000000000e83', '00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e71', 'Root canal', '00000000-0000-4000-8000-000000000e34', now() - interval '1 hour', null, null, null),
  ('00000000-0000-4000-8000-000000000e84', '00000000-0000-4000-8000-000000000e42', null, 'Other clinic procedure', '00000000-0000-4000-8000-000000000e33', now(), null, null, null),
  ('00000000-0000-4000-8000-000000000e85', '00000000-0000-4000-8000-000000000e41', null, 'Extraction A', '00000000-0000-4000-8000-000000000e31', date_trunc('second', now() - interval '3 hours') + interval '900 milliseconds', null, null, null),
  ('00000000-0000-4000-8000-000000000e86', '00000000-0000-4000-8000-000000000e41', null, 'Extraction B', '00000000-0000-4000-8000-000000000e31', date_trunc('second', now() - interval '3 hours') + interval '500 milliseconds', null, null, null);
insert into public.procedure_event_items (clinic_id, event_id, product_id, qty) values
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e81', '00000000-0000-4000-8000-000000000e61', 1),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e82', '00000000-0000-4000-8000-000000000e61', 1),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e82', '00000000-0000-4000-8000-000000000e64', 0),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e83', '00000000-0000-4000-8000-000000000e61', 2),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e83', '00000000-0000-4000-8000-000000000e62', 1),
  ('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e83', '00000000-0000-4000-8000-000000000e63', 2);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

select ok(not has_function_privilege('anon', 'public.procedure_templates_list(uuid)', 'execute'), 'anon cannot list templates');
select ok(not has_function_privilege('anon', 'public.procedure_history(uuid, uuid, integer)', 'execute'), 'nor read the history');
select ok(has_function_privilege('authenticated', 'public.procedure_history(uuid, uuid, integer)', 'execute'), 'members can');

select pg_temp.act_as('00000000-0000-4000-8000-000000000e32');
select results_eq(
  $$ select name, item_count, not_available_count, run_out_count from public.procedure_templates_list('00000000-0000-4000-8000-000000000e41') $$,
  $$ values ('Root canal', 4, 1, 1), ('Crown', 2, 0, 1), ('Filling', 0, 0, 0) $$,
  'staff see the active templates in creation order with their supply counts and shortages');
select is(
  (select count(*) from public.procedure_templates_list('00000000-0000-4000-8000-000000000e41') where name = 'Retired'), 0::bigint,
  'an archived template is left out');
select is(
  (select item_count from public.procedure_templates_list('00000000-0000-4000-8000-000000000e41') where name = 'Root canal'), 4,
  'an archived product is not a supply');
select is(
  (select run_out_count from public.procedure_templates_list('00000000-0000-4000-8000-000000000e41') where name = 'Crown'), 1,
  'taking the last unopened bottle of a multi-use product new uses it up');
select results_eq(
  $$ select name, started_by_name, item_count, cancelled_at is not null from public.procedure_history('00000000-0000-4000-8000-000000000e41') $$,
  $$ values ('Root canal', '', 3, false), ('Extraction A', 'Sarah Mitchell', 0, false), ('Extraction B', 'Sarah Mitchell', 0, false),
            ('Crown', 'Michael Reyes', 2, true), ('Filling', 'Sarah Mitchell', 1, false) $$,
  'history is newest first with who started each, its supply count and whether it was cancelled');
select results_eq(
  $$ select name from public.procedure_history('00000000-0000-4000-8000-000000000e41', null, 2) $$,
  $$ values ('Root canal'), ('Extraction A') $$,
  'a page holds at most the limit');
select results_eq(
  $$ select name from public.procedure_history('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e85', 2) $$,
  $$ values ('Extraction B'), ('Crown') $$,
  'the next page starts with the procedure started in the same second as the last row');
select results_eq(
  $$ select name from public.procedure_history('00000000-0000-4000-8000-000000000e41', '00000000-0000-4000-8000-000000000e82', 2) $$,
  $$ values ('Filling') $$,
  'and the last page ends with the oldest');
select is(
  (select count(*) from public.procedure_history('00000000-0000-4000-8000-000000000e41', null, 0)), 1::bigint,
  'a limit below 1 still returns one row');
select is((select count(*) from public.procedure_templates_list('00000000-0000-4000-8000-000000000e42')), 0::bigint,
  'another clinic''s templates stay hidden');
select is((select count(*) from public.procedure_history('00000000-0000-4000-8000-000000000e42')), 0::bigint,
  'and so does its history');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000e33');
select is((select count(*) from public.procedure_templates_list('00000000-0000-4000-8000-000000000e41')), 0::bigint,
  'Other Dental sees none of Smile Dental''s templates');
select is((select count(*) from public.procedure_history('00000000-0000-4000-8000-000000000e41')), 0::bigint,
  'nor its procedures');
select results_eq(
  $$ select name from public.procedure_templates_list('00000000-0000-4000-8000-000000000e42') $$,
  $$ values ('Other clinic template') $$,
  'it sees its own');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000000e34');
select is((select count(*) from public.procedure_history('00000000-0000-4000-8000-000000000e41')), 0::bigint,
  'someone who left the clinic sees nothing');
reset role;

select * from finish();
rollback;
