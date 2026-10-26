-- Two clinics, an admin and a staff member in each: nobody reads across clinics, every "no" cell of the
-- PRD §2 role table fails for Staff, stock tables take no direct writes, the last admin stays, and a
-- clinic whose trial ended takes no writes.
begin;
select plan(60);

-- Fixtures (as the owner) --------------------------------------------------------------------------
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin1@dentory.test'),
  ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'staff1@dentory.test'),
  ('00000000-0000-4000-8000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin2@dentory.test'),
  ('00000000-0000-4000-8000-0000000000b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'staff2@dentory.test');
insert into public.profiles (user_id, full_name) values
  ('00000000-0000-4000-8000-0000000000a1', 'Michael'), ('00000000-0000-4000-8000-0000000000b1', 'Sarah'),
  ('00000000-0000-4000-8000-0000000000a2', 'Dana'), ('00000000-0000-4000-8000-0000000000b2', 'Lee');
insert into public.clinics (id, name, country, currency) values
  ('00000000-0000-4000-8000-0000000000c1', 'Smile Dental', 'US', 'USD'),
  ('00000000-0000-4000-8000-0000000000c2', 'Other Dental', 'CA', 'CAD');
insert into public.memberships (clinic_id, user_id, email, role, status) values
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', 'admin1@dentory.test', 'admin', 'active'),
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000b1', 'staff1@dentory.test', 'staff', 'active'),
  ('00000000-0000-4000-8000-0000000000c2', '00000000-0000-4000-8000-0000000000a2', 'admin2@dentory.test', 'admin', 'active'),
  ('00000000-0000-4000-8000-0000000000c2', '00000000-0000-4000-8000-0000000000b2', 'staff2@dentory.test', 'staff', 'active');
insert into public.products (id, clinic_id, name, unit) values
  ('00000000-0000-4000-8000-0000000000d1', '00000000-0000-4000-8000-0000000000c1', 'Septocaine 4% 1:100,000', 'cartridges'),
  ('00000000-0000-4000-8000-0000000000d3', '00000000-0000-4000-8000-0000000000c1', 'Nitrile gloves M', 'boxes'),
  ('00000000-0000-4000-8000-0000000000d2', '00000000-0000-4000-8000-0000000000c2', 'Composite A2', 'syringes');
insert into public.batches (clinic_id, product_id, qty) values
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d1', 54),
  ('00000000-0000-4000-8000-0000000000c2', '00000000-0000-4000-8000-0000000000d2', 2);
insert into public.procedure_templates (id, clinic_id, name) values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000c1', 'Root canal');
insert into public.invoices (id, clinic_id, source, created_by) values
  ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000c1', 'manual', '00000000-0000-4000-8000-0000000000a1');
insert into public.to_buy_items (id, clinic_id, product_id, qty) values
  ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d1', 6);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

-- Helpers ------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-0000000000a1');
select is(public.current_role_in('00000000-0000-4000-8000-0000000000c1'), 'admin', 'admin1 is admin in clinic 1');
select is(public.current_role_in('00000000-0000-4000-8000-0000000000c2'), null, 'admin1 has no role in clinic 2');
select ok(public.is_admin('00000000-0000-4000-8000-0000000000c1'), 'is_admin is true for an admin');
select ok(public.clinic_can_write('00000000-0000-4000-8000-0000000000c1'), 'a clinic in trial can be written');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000000000b1');
select ok(not public.is_admin('00000000-0000-4000-8000-0000000000c1'), 'is_admin is false for staff');
select ok(public.is_member('00000000-0000-4000-8000-0000000000c1'), 'is_member is true for staff');
reset role;

-- No cross-clinic reads ----------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-0000000000b1');
select results_eq($$ select id from public.clinics order by id $$, $$ values ('00000000-0000-4000-8000-0000000000c1'::uuid) $$, 'staff1 sees only clinic 1');
select results_eq($$ select id from public.products order by id $$, $$ values ('00000000-0000-4000-8000-0000000000d1'::uuid), ('00000000-0000-4000-8000-0000000000d3'::uuid) $$, 'staff1 sees only clinic 1 products');
select is((select count(*) from public.batches), 1::bigint, 'staff1 sees only clinic 1 batches');
select is((select count(*) from public.product_stock), 2::bigint, 'the stock view follows the same rule');
select is((select count(*) from public.memberships), 2::bigint, 'staff1 sees the team of clinic 1 only');
select is((select count(*) from public.profiles), 2::bigint, 'staff1 sees the profiles of clinic 1 only');
select is((select count(*) from public.invoices), 0::bigint, 'staff sees no invoices');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000000000a2');
select is((select count(*) from public.products where clinic_id = '00000000-0000-4000-8000-0000000000c1'), 0::bigint, 'admin2 sees nothing of clinic 1');
select is((select count(*) from public.to_buy_items), 0::bigint, 'admin2 sees no To buy items of clinic 1');
reset role;

-- Staff: every "no" cell fails ---------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-0000000000b1');
select throws_ok($$ insert into public.memberships (clinic_id, email, role) values ('00000000-0000-4000-8000-0000000000c1', 'new@clinic.com', 'staff') $$,
  '42501', null, 'staff cannot invite');
select throws_ok($$ update public.memberships set role = 'admin' where user_id = '00000000-0000-4000-8000-0000000000b1' $$,
  '42501', null, 'staff cannot change roles');
select throws_ok($$ insert into public.procedure_templates (clinic_id, name) values ('00000000-0000-4000-8000-0000000000c1', 'Filling') $$,
  '42501', null, 'staff cannot create templates');
select throws_ok($$ update public.procedure_templates set name = 'Root canal 2' where id = '00000000-0000-4000-8000-0000000000e1' $$,
  '42501', null, 'staff cannot edit templates');
select throws_ok($$ insert into public.products (clinic_id, name, unit) values ('00000000-0000-4000-8000-0000000000c1', 'Gloves', 'boxes') $$,
  '42501', null, 'staff cannot create products');
select throws_ok($$ update public.products set name = 'x' where id = '00000000-0000-4000-8000-0000000000d1' $$,
  '42501', null, 'staff cannot edit products');
select throws_ok($$ update public.to_buy_items set status = 'ordered', ordered_at = now(), ordered_by = '00000000-0000-4000-8000-0000000000b1' where id = '00000000-0000-4000-8000-000000000011' $$,
  '42501', null, 'staff cannot mark as ordered');
select throws_ok($$ insert into public.invoices (clinic_id, source, created_by) values ('00000000-0000-4000-8000-0000000000c1', 'manual', '00000000-0000-4000-8000-0000000000b1') $$,
  '42501', null, 'staff cannot receive a delivery');
select throws_ok($$ update public.clinics set name = 'Renamed' where id = '00000000-0000-4000-8000-0000000000c1' $$,
  '42501', null, 'staff cannot change clinic settings');
select throws_ok($$ insert into public.export_jobs (clinic_id, requested_by) values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000b1') $$,
  '42501', null, 'staff cannot export');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('invoices', '00000000-0000-4000-8000-0000000000c1/00000000-0000-4000-8000-0000000000f2/page-1.jpg') $$,
  '42501', null, 'staff cannot upload invoices');
-- and the "yes" cells work
select lives_ok($$ update public.to_buy_items set qty = 8, qty_edited = true where id = '00000000-0000-4000-8000-000000000011' $$,
  'staff can change a To buy quantity');
select lives_ok($$ insert into public.to_buy_items (clinic_id, product_id, qty, source, added_by) values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d3', 1, 'manual', '00000000-0000-4000-8000-0000000000b1') $$,
  'staff adds to To buy');
select throws_ok($$ insert into public.to_buy_items (clinic_id, product_id, qty, status, ordered_at, ordered_by) values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d1', 1, 'ordered', now(), '00000000-0000-4000-8000-0000000000b1') $$,
  '42501', null, 'staff cannot add an item as already ordered');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('logos', '00000000-0000-4000-8000-0000000000c1/logo.png') $$,
  '42501', null, 'staff cannot upload a logo');
select lives_ok($$ insert into public.alert_reads (clinic_id, user_id) values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000b1') $$,
  'staff keeps their own bell marker');
reset role;

-- Stock tables take no direct writes from anyone signed in ----------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-0000000000a1');
select throws_ok($$ insert into public.batches (clinic_id, product_id, qty) values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d1', 1) $$,
  '42501', null, 'even an admin cannot insert batches directly');
select throws_ok($$ update public.batches set qty = 1 $$, '42501', null, 'nor update them');
select throws_ok($$ insert into public.open_items (clinic_id, product_id, opened_by) values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d1', '00000000-0000-4000-8000-0000000000a1') $$,
  '42501', null, 'nor open items');
select throws_ok($$ insert into public.transactions (clinic_id, product_id, type, delta, qty_before, qty_after, by_user, ref_type, action_id) values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000d1', 'count', 1, 0, 1, '00000000-0000-4000-8000-0000000000a1', 'count_session', gen_random_uuid()) $$,
  '42501', null, 'nor the ledger');
select throws_ok($$ insert into public.procedure_events (clinic_id, name, started_by) values ('00000000-0000-4000-8000-0000000000c1', 'Root canal', '00000000-0000-4000-8000-0000000000a1') $$,
  '42501', null, 'nor procedure events');
-- Admin "yes" cells. Inviting goes through invite_member and its token alone (MS-151, 09_invitations_test.sql).
select throws_ok($$ insert into public.memberships (clinic_id, email, role, invited_by) values ('00000000-0000-4000-8000-0000000000c1', 'new@clinic.com', 'staff', '00000000-0000-4000-8000-0000000000a1') $$,
  '42501', null, 'admin invites only through invite_member, never with a row of their own');
select lives_ok($$ insert into public.products (clinic_id, name, unit) values ('00000000-0000-4000-8000-0000000000c1', 'Gloves', 'boxes') $$,
  'admin creates products');
select lives_ok($$ update public.to_buy_items set status = 'ordered', ordered_at = now(), ordered_by = '00000000-0000-4000-8000-0000000000a1' where id = '00000000-0000-4000-8000-000000000011' $$,
  'admin marks as ordered');
select throws_ok($$ update public.clinics set name = 'Smile Dental Group' where id = '00000000-0000-4000-8000-0000000000c1' $$,
  '42501', null, 'admin changes clinic settings only through clinic_settings_save (MS-151, 28_clinic_settings_test.sql)');
select lives_ok($$ update public.clinics set logo_path = '00000000-0000-4000-8000-0000000000c1/logo.jpg' where id = '00000000-0000-4000-8000-0000000000c1' $$,
  'admin points the clinic at its logo');
select throws_ok($$ update public.clinics set subscription_status = 'active' where id = '00000000-0000-4000-8000-0000000000c1' $$,
  '42501', null, 'admin cannot change the subscription');
select throws_ok($$ update public.clinics set trial_ends_at = '2099-01-01' where id = '00000000-0000-4000-8000-0000000000c1' $$,
  '42501', null, 'admin cannot extend the trial');
select throws_ok($$ update public.clinics set promo_lifetime_50 = true where id = '00000000-0000-4000-8000-0000000000c1' $$,
  '42501', null, 'admin cannot grant the promo');
select lives_ok($$ insert into storage.objects (bucket_id, name) values ('logos', '00000000-0000-4000-8000-0000000000c1/logo.png') $$,
  'admin uploads the logo');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('logos', '00000000-0000-4000-8000-0000000000c2/logo.png') $$,
  '42501', null, 'but not another clinic''s logo');
select lives_ok($$ insert into storage.objects (bucket_id, name) values ('invoices', '00000000-0000-4000-8000-0000000000c1/00000000-0000-4000-8000-0000000000f2/page-1.jpg') $$,
  'admin uploads invoices');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('invoices', '00000000-0000-4000-8000-0000000000c2/00000000-0000-4000-8000-0000000000f2/page-1.jpg') $$,
  '42501', null, 'but not into another clinic''s folder');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-0000000000b1');
select is((select count(*) from storage.objects where bucket_id = 'logos'), 1::bigint, 'staff sees the clinic logo');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000000000b2');
select is((select count(*) from storage.objects where bucket_id = 'logos'), 0::bigint, 'another clinic does not see it');
reset role;

-- The last admin stays -----------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-0000000000a1');
select throws_ok($$ update public.memberships set role = 'staff' where user_id = '00000000-0000-4000-8000-0000000000a1' $$,
  '23001', null, 'the last admin cannot be demoted');
select throws_ok($$ select public.team_remove((select id from public.memberships where user_id = '00000000-0000-4000-8000-0000000000a1')) $$,
  '22023', 'A clinic needs at least one admin.', 'the last admin cannot be removed');
select throws_ok($$ delete from public.memberships where user_id = '00000000-0000-4000-8000-0000000000a1' $$,
  '42501', null, 'nor deleted: removing someone keeps their row, revoked (MS-151)');
select lives_ok($$ update public.memberships set role = 'admin' where user_id = '00000000-0000-4000-8000-0000000000b1' $$,
  'a second admin can be made');
select lives_ok($$ update public.memberships set role = 'staff' where user_id = '00000000-0000-4000-8000-0000000000a1' $$,
  'then the first one can step down');
reset role;

-- A clinic past its trial is read-only (MS-100 G5) -------------------------------------------------
update public.clinics set trial_ends_at = now() - interval '1 day' where id = '00000000-0000-4000-8000-0000000000c2';
select pg_temp.act_as('00000000-0000-4000-8000-0000000000a2');
select ok(not public.clinic_can_write('00000000-0000-4000-8000-0000000000c2'), 'a trial that ended without payment cannot be written');
select throws_ok($$ insert into public.products (clinic_id, name, unit) values ('00000000-0000-4000-8000-0000000000c2', 'Gloves', 'boxes') $$,
  '42501', null, 'writes are refused once the trial ended');
reset role;
update public.clinics set subscription_status = 'read_only' where id = '00000000-0000-4000-8000-0000000000c2';
select pg_temp.act_as('00000000-0000-4000-8000-0000000000a2');
select ok(not public.clinic_can_write('00000000-0000-4000-8000-0000000000c2'), 'clinic_can_write is false after the trial');
select throws_ok($$ insert into public.products (clinic_id, name, unit) values ('00000000-0000-4000-8000-0000000000c2', 'Gloves', 'boxes') $$,
  '42501', null, 'writes are refused in read-only mode');
select is((select count(*) from public.products), 1::bigint, 'reading still works in read-only mode');
reset role;

select * from finish();
rollback;
