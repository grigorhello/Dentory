-- MS-134 · activity_history: the ledger newest first, a procedure's rows one per action, the filters, one product's
-- rows, pages that continue after a row or a group, clinic-isolated.
begin;
select plan(20);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000013401', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000013402', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000013403', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elsewhere@dentory.test');
insert into public.clinics (id, name, country, currency, time_zone) values
  ('00000000-0000-4000-8000-000000013411', 'Smile Dental', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-000000013412', 'Other Dental', 'CA', 'CAD', 'America/Toronto');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000013411', '00000000-0000-4000-8000-000000013401', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000013411', '00000000-0000-4000-8000-000000013402', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000013412', '00000000-0000-4000-8000-000000013403', 'elsewhere@dentory.test', 'Dr. Other', 'admin', 'active');
insert into public.products (id, clinic_id, name, unit, tracking) values
  ('00000000-0000-4000-8000-000000013421', '00000000-0000-4000-8000-000000013411', 'Septocaine', 'cartridges', 'countable'),
  ('00000000-0000-4000-8000-000000013422', '00000000-0000-4000-8000-000000013411', 'Gloves', 'boxes', 'countable'),
  ('00000000-0000-4000-8000-000000013423', '00000000-0000-4000-8000-000000013411', 'Bonding agent', 'bottles', 'multi_use'),
  ('00000000-0000-4000-8000-000000013424', '00000000-0000-4000-8000-000000013411', 'Composite A2', 'syringes', 'multi_use'),
  ('00000000-0000-4000-8000-000000013425', '00000000-0000-4000-8000-000000013412', 'Other gloves', 'boxes', 'countable');
-- A Root canal yesterday (Sepocaine -2, Gloves -2), edited 20 hours ago (+1, -2); a Crown two days ago, cancelled
-- a day and a half ago.
insert into public.procedure_events (id, clinic_id, name, started_by, started_at, cancelled_at, cancelled_by, cancel_note) values
  ('00000000-0000-4000-8000-000000013431', '00000000-0000-4000-8000-000000013411', 'Root canal', '00000000-0000-4000-8000-000000013401', now() - interval '1 day', null, null, null),
  ('00000000-0000-4000-8000-000000013432', '00000000-0000-4000-8000-000000013411', 'Crown', '00000000-0000-4000-8000-000000013401', now() - interval '2 days', now() - interval '36 hours', '00000000-0000-4000-8000-000000013402', 'Logged by mistake');

-- The ledger, oldest first. Ids end in their order so same-instant rows sort predictably (id descending).
create function pg_temp.tx(
  p_id text, p_product text, p_type public.transaction_type, p_delta numeric, p_before numeric, p_user text,
  p_ago interval, p_ref_type public.transaction_ref_type, p_ref_id text, p_label text, p_reason text, p_note text,
  p_action text, p_clinic text default '00000000-0000-4000-8000-000000013411'
) returns void language sql as $$
  insert into public.transactions (id, clinic_id, product_id, type, delta, qty_before, qty_after, by_user, at, ref_type,
    ref_id, ref_label, reason, note, action_id)
  values (p_id::uuid, p_clinic::uuid, p_product::uuid, p_type, p_delta, p_before, p_before + p_delta, p_user::uuid,
    now() - p_ago, p_ref_type, p_ref_id::uuid, p_label, p_reason, p_note, p_action::uuid);
$$;
-- Received three days ago: two lines of one delivery.
select pg_temp.tx('00000000-0000-4000-8000-000000013441', '00000000-0000-4000-8000-000000013421', 'receiving', 20, 30, '00000000-0000-4000-8000-000000013401', interval '3 days', 'manual', null, 'Receive manually', null, null, '00000000-0000-4000-8000-000000013451');
select pg_temp.tx('00000000-0000-4000-8000-000000013442', '00000000-0000-4000-8000-000000013422', 'receiving', 10, 0, '00000000-0000-4000-8000-000000013401', interval '3 days', 'manual', null, 'Receive manually', null, null, '00000000-0000-4000-8000-000000013451');
-- The Crown: started, then cancelled with a note.
select pg_temp.tx('00000000-0000-4000-8000-000000013443', '00000000-0000-4000-8000-000000013421', 'procedure', -3, 50, '00000000-0000-4000-8000-000000013401', interval '2 days', 'procedure_event', '00000000-0000-4000-8000-000000013432', 'Crown', null, null, '00000000-0000-4000-8000-000000013432');
select pg_temp.tx('00000000-0000-4000-8000-000000013444', '00000000-0000-4000-8000-000000013421', 'cancellation', 3, 47, '00000000-0000-4000-8000-000000013402', interval '36 hours', 'procedure_event', '00000000-0000-4000-8000-000000013432', 'Crown', null, 'Logged by mistake', '00000000-0000-4000-8000-000000013452');
-- The Root canal: started, then edited.
select pg_temp.tx('00000000-0000-4000-8000-000000013445', '00000000-0000-4000-8000-000000013421', 'procedure', -2, 50, '00000000-0000-4000-8000-000000013401', interval '1 day', 'procedure_event', '00000000-0000-4000-8000-000000013431', 'Root canal', null, null, '00000000-0000-4000-8000-000000013431');
select pg_temp.tx('00000000-0000-4000-8000-000000013446', '00000000-0000-4000-8000-000000013422', 'procedure', -2, 10, '00000000-0000-4000-8000-000000013401', interval '1 day', 'procedure_event', '00000000-0000-4000-8000-000000013431', 'Root canal', null, null, '00000000-0000-4000-8000-000000013431');
select pg_temp.tx('00000000-0000-4000-8000-000000013447', '00000000-0000-4000-8000-000000013421', 'procedure', 1, 48, '00000000-0000-4000-8000-000000013402', interval '20 hours', 'procedure_event', '00000000-0000-4000-8000-000000013431', 'Edited usage · Root canal', null, null, '00000000-0000-4000-8000-000000013453');
select pg_temp.tx('00000000-0000-4000-8000-000000013448', '00000000-0000-4000-8000-000000013422', 'procedure', -2, 8, '00000000-0000-4000-8000-000000013402', interval '20 hours', 'procedure_event', '00000000-0000-4000-8000-000000013431', 'Edited usage · Root canal', null, null, '00000000-0000-4000-8000-000000013453');
-- A physical count, a damaged syringe and its Undo, a bottle opened, a disposal.
select pg_temp.tx('00000000-0000-4000-8000-000000013449', '00000000-0000-4000-8000-000000013421', 'count', -2, 43, '00000000-0000-4000-8000-000000013402', interval '12 hours', 'count_session', '00000000-0000-4000-8000-000000013454', 'Physical count', 'Physical count', null, '00000000-0000-4000-8000-000000013454');
select pg_temp.tx('00000000-0000-4000-8000-00000001344a', '00000000-0000-4000-8000-000000013424', 'adjustment', -1, 3, '00000000-0000-4000-8000-000000013401', interval '6 hours', 'manual', null, 'Damaged', 'Damaged', null, '00000000-0000-4000-8000-000000013455');
select pg_temp.tx('00000000-0000-4000-8000-00000001344b', '00000000-0000-4000-8000-000000013424', 'adjustment', 1, 2, '00000000-0000-4000-8000-000000013401', interval '6 hours' - interval '5 seconds', 'undo', '00000000-0000-4000-8000-000000013455', 'Undo · Damaged', 'Damaged', null, '00000000-0000-4000-8000-000000013456');
select pg_temp.tx('00000000-0000-4000-8000-00000001344c', '00000000-0000-4000-8000-000000013423', 'adjustment', 0, 2, '00000000-0000-4000-8000-000000013402', interval '2 hours', 'manual', null, 'Opened a new bottle', null, null, '00000000-0000-4000-8000-000000013457');
select pg_temp.tx('00000000-0000-4000-8000-00000001344d', '00000000-0000-4000-8000-000000013421', 'disposal', -5, 41, '00000000-0000-4000-8000-000000013401', interval '1 hour', 'manual', null, 'Mark disposed', 'Expired', null, '00000000-0000-4000-8000-000000013458');
select pg_temp.tx('00000000-0000-4000-8000-00000001344e', '00000000-0000-4000-8000-000000013425', 'receiving', 9, 0, '00000000-0000-4000-8000-000000013403', interval '1 hour', 'manual', null, 'Receive manually', null, null, '00000000-0000-4000-8000-000000013459', '00000000-0000-4000-8000-000000013412');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

select ok(not has_function_privilege('anon', 'public.activity_history(uuid, text, uuid, uuid, integer)', 'execute'), 'anon cannot read the history');
select ok(has_function_privilege('authenticated', 'public.activity_history(uuid, text, uuid, uuid, integer)', 'execute'), 'members can');

select pg_temp.act_as('00000000-0000-4000-8000-000000013402');
select results_eq(
  $$ select subject, type::text, delta from public.activity_history('00000000-0000-4000-8000-000000013411') $$,
  $$ values ('Septocaine', 'disposal', -5::numeric), ('Bonding agent', 'adjustment', 0), ('Composite A2', 'adjustment', 1),
            ('Composite A2', 'adjustment', -1), ('Septocaine', 'count', -2), ('Root canal', 'procedure', -1),
            ('Root canal', 'procedure', -4), ('Crown', 'cancellation', 3), ('Crown', 'procedure', -3),
            ('Gloves', 'receiving', 10), ('Septocaine', 'receiving', 20) $$,
  'Staff read the ledger newest first, a procedure''s rows one per action with their deltas summed');
select results_eq(
  $$ select id, is_edit, product_id is null, ref_type::text from public.activity_history('00000000-0000-4000-8000-000000013411')
      where subject = 'Root canal' $$,
  $$ values ('00000000-0000-4000-8000-000000013453'::uuid, true, true, 'procedure_event'),
            ('00000000-0000-4000-8000-000000013431'::uuid, false, true, 'procedure_event') $$,
  'a procedure''s start and its edit are rows of their own, named by their action, the edit marked');
select is(
  (select note from public.activity_history('00000000-0000-4000-8000-000000013411') where type = 'cancellation'),
  'Logged by mistake', 'a cancellation carries its note');
select results_eq(
  $$ select qty_before, qty_after, by_name, ref_label from public.activity_history('00000000-0000-4000-8000-000000013411')
      where type = 'count' $$,
  $$ values (43::numeric, 41::numeric, 'Michael Reyes', 'Physical count') $$,
  'a count carries what it was and what it became, and who counted');
select results_eq(
  $$ select ref_type::text, ref_label, reason from public.activity_history('00000000-0000-4000-8000-000000013411')
      where subject = 'Composite A2' $$,
  $$ values ('undo', 'Undo · Damaged', 'Damaged'), ('manual', 'Damaged', 'Damaged') $$,
  'an Undo keeps its original''s type and names what it reverses');
select is(
  (select by_name from public.activity_history('00000000-0000-4000-8000-000000013411') where type = 'disposal'),
  'Sarah Mitchell', 'every row names who did it');
select is((select count(*) from public.activity_history('00000000-0000-4000-8000-000000013411', 'receiving'))::integer, 2,
  'Receiving lists the delivery''s lines');
select results_eq(
  $$ select subject, type::text from public.activity_history('00000000-0000-4000-8000-000000013411', 'procedures') $$,
  $$ values ('Root canal', 'procedure'), ('Root canal', 'procedure'), ('Crown', 'cancellation'), ('Crown', 'procedure') $$,
  'Procedures lists starts, edits and cancellations');
select is((select count(*) from public.activity_history('00000000-0000-4000-8000-000000013411', 'counts'))::integer, 1,
  'Counts lists the count');
select results_eq(
  $$ select subject, type::text from public.activity_history('00000000-0000-4000-8000-000000013411', 'adjustments') $$,
  $$ values ('Septocaine', 'disposal'), ('Bonding agent', 'adjustment'), ('Composite A2', 'adjustment'),
            ('Composite A2', 'adjustment') $$,
  'Adjustments lists disposals, a bottle opened, an adjustment and its Undo');
select results_eq(
  $$ select type::text, delta, ref_label from public.activity_history('00000000-0000-4000-8000-000000013411', null,
       '00000000-0000-4000-8000-000000013421') $$,
  $$ values ('disposal', -5::numeric, 'Mark disposed'), ('count', -2, 'Physical count'),
            ('procedure', 1, 'Edited usage · Root canal'), ('procedure', -2, 'Root canal'),
            ('cancellation', 3, 'Crown'), ('procedure', -3, 'Crown'), ('receiving', 20, 'Receive manually') $$,
  'one product''s history lists its own rows, procedures included, ungrouped');
select is(
  (select count(*) from public.activity_history('00000000-0000-4000-8000-000000013411', 'procedures',
     '00000000-0000-4000-8000-000000013422'))::integer, 2, 'a filter and a product combine');
select results_eq(
  $$ select subject from public.activity_history('00000000-0000-4000-8000-000000013411', null, null, null, 3) $$,
  $$ values ('Septocaine'), ('Bonding agent'), ('Composite A2') $$,
  'a page holds at most the limit');
select results_eq(
  $$ select subject, delta from public.activity_history('00000000-0000-4000-8000-000000013411', null, null,
       '00000000-0000-4000-8000-00000001344b', 3) $$,
  $$ values ('Composite A2', -1::numeric), ('Septocaine', -2), ('Root canal', -1) $$,
  'the next page continues after the last row');
select results_eq(
  $$ select subject, type::text from public.activity_history('00000000-0000-4000-8000-000000013411', null, null,
       '00000000-0000-4000-8000-000000013431', 2) $$,
  $$ values ('Crown', 'cancellation'), ('Crown', 'procedure') $$,
  'and after a procedure''s row, named by its action');
select results_eq(
  $$ select subject from public.activity_history('00000000-0000-4000-8000-000000013411', null, null,
       '00000000-0000-4000-8000-000000013442', 5) $$,
  $$ values ('Septocaine') $$,
  'rows of the same instant neither repeat nor hide');
select is((select count(*) from public.activity_history('00000000-0000-4000-8000-000000013411', null, null, null, 0))::integer, 1,
  'a limit below 1 still returns one row');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000013403');
select is((select count(*) from public.activity_history('00000000-0000-4000-8000-000000013411'))::integer, 0,
  'another clinic sees none of it');
reset role;

select * from finish();
rollback;
