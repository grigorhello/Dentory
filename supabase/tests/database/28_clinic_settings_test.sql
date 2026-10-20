-- MS-139 · Clinic settings: who may save, the sentence and field of each refusal, what is stored, and the expiry
-- alerts following a new expiry warning or time zone at once.
begin;
select plan(18);

insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-4000-8000-000000017401', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@dentory.test'),
  ('00000000-0000-4000-8000-000000017402', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'michael@dentory.test'),
  ('00000000-0000-4000-8000-000000017403', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'solo@dentory.test');
insert into public.clinics (id, name, city, country, currency, time_zone) values
  ('00000000-0000-4000-8000-000000017411', 'Smile Dental', 'Toronto', 'CA', 'CAD', 'America/Toronto'),
  ('00000000-0000-4000-8000-000000017412', 'Solo Dental', 'Halifax', 'CA', 'CAD', 'America/Halifax');
insert into public.memberships (clinic_id, user_id, email, full_name, role, status) values
  ('00000000-0000-4000-8000-000000017411', '00000000-0000-4000-8000-000000017401', 'sarah@dentory.test', 'Sarah Mitchell', 'admin', 'active'),
  ('00000000-0000-4000-8000-000000017411', '00000000-0000-4000-8000-000000017402', 'michael@dentory.test', 'Michael Reyes', 'staff', 'active'),
  ('00000000-0000-4000-8000-000000017412', '00000000-0000-4000-8000-000000017403', 'solo@dentory.test', 'Solo Admin', 'admin', 'active');
insert into public.products (id, clinic_id, name, unit, tracking) values
  ('00000000-0000-4000-8000-000000017421', '00000000-0000-4000-8000-000000017411', 'Septocaine', 'cartridges', 'countable');
-- A batch ending this month: within 30, 60 and 90 days, so each chosen threshold has its alert.
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000017431', '00000000-0000-4000-8000-000000017411', '00000000-0000-4000-8000-000000017421',
   date_trunc('month', now() at time zone 'America/Toronto')::date, 'S1', 5);
select public.refresh_product('00000000-0000-4000-8000-000000017421');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;
create function pg_temp.open_thresholds(p_batch text) returns integer[] language sql as $$
  select coalesce(array_agg(threshold_days order by threshold_days), '{}')
  from public.alerts
  where batch_id = p_batch::uuid and kind = 'expiring' and resolved_at is null;
$$;
create function pg_temp.save(
  p_name text, p_thresholds integer[], p_time_zone text default 'America/Toronto', p_country text default 'ca',
  p_currency text default 'cad'
) returns void language sql as $$
  select public.clinic_settings_save('00000000-0000-4000-8000-000000017411', p_name, '  ', p_country, p_currency,
    p_time_zone, p_thresholds, false);
$$;
-- The field a refusal names (its hint), which the app shows the sentence under.
create function pg_temp.field_of(p_sql text) returns text language plpgsql as $$
declare
  v_hint text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint;
  return v_hint;
end;
$$;

select ok(not has_function_privilege('anon', 'public.clinic_settings_save(uuid, text, text, text, text, text, integer[], boolean)', 'execute'),
  'anon cannot save settings');
select is(pg_temp.open_thresholds('00000000-0000-4000-8000-000000017431'), array[30, 60, 90],
  'with 30, 60 and 90 days the batch has three expiring alerts');

-- Only the clinic's admin saves.
select pg_temp.act_as('00000000-0000-4000-8000-000000017402');
select throws_ok($$select pg_temp.save('Smile Dental', '{90}')$$, '42501', 'Only an admin can change clinic settings',
  'Staff cannot save settings');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000017403');
select throws_ok($$select pg_temp.save('Smile Dental', '{90}')$$, '42501', 'Only an admin can change clinic settings',
  'another clinic''s admin cannot either');
reset role;

-- Each refusal says what to do and names its field.
select pg_temp.act_as('00000000-0000-4000-8000-000000017401');
select throws_ok($$select pg_temp.save('   ', '{90}')$$, '22023', 'Enter the clinic name', 'the name is required');
select is(pg_temp.field_of($$select pg_temp.save('   ', '{90}')$$), 'name', 'under the name field');
select throws_ok($$select pg_temp.save('Smile Dental', '{90}', p_country => 'Canada')$$, '22023', 'Choose a country',
  'the country is a two-letter code');
select throws_ok($$select pg_temp.save('Smile Dental', '{90}', p_currency => 'dollars')$$, '22023', 'Choose a currency',
  'the currency is a three-letter code');
select throws_ok($$select pg_temp.save('Smile Dental', '{90}', p_time_zone => 'Mars/Base')$$, '22023', 'Choose a time zone',
  'the time zone must exist');
select is(pg_temp.field_of($$select pg_temp.save('Smile Dental', '{90}', p_time_zone => 'Mars/Base')$$), 'timeZone',
  'under the time zone field');
select throws_ok($$select pg_temp.save('Smile Dental', '{30}')$$, '22023', 'Choose an expiry warning',
  'the expiry warning is one of the three choices');

-- A save, and the alerts following the new warning at once.
select lives_ok($$select pg_temp.save('  Smile Dental Group ', '{90}')$$, 'the admin saves');
reset role;
select results_eq(
  $$select name, city, country::text, currency::text, time_zone, expiry_thresholds, email_digest
    from public.clinics where id = '00000000-0000-4000-8000-000000017411'$$,
  $$values ('Smile Dental Group', null::text, 'CA', 'CAD', 'America/Toronto', array[90], false)$$,
  'the name trimmed, an empty city cleared, the codes in capitals'
);
select is(pg_temp.open_thresholds('00000000-0000-4000-8000-000000017431'), array[90],
  '"90 days only" closes the 30 and 60 day alerts');
select pg_temp.act_as('00000000-0000-4000-8000-000000017401');
select pg_temp.save('Smile Dental', '{30,60,90}');
reset role;
select is(pg_temp.open_thresholds('00000000-0000-4000-8000-000000017431'), array[30, 60, 90],
  'and "30, 60 and 90 days" opens them again');

-- A new time zone re-reads every batch too: one stocked without a refresh gets its alerts.
insert into public.batches (id, clinic_id, product_id, expiry_month, lot, qty) values
  ('00000000-0000-4000-8000-000000017432', '00000000-0000-4000-8000-000000017411', '00000000-0000-4000-8000-000000017421',
   date_trunc('month', now() at time zone 'America/Toronto')::date, 'S2', 2);
select is(pg_temp.open_thresholds('00000000-0000-4000-8000-000000017432'), '{}'::integer[], 'a batch not refreshed yet');
select pg_temp.act_as('00000000-0000-4000-8000-000000017401');
select pg_temp.save('Smile Dental', '{30,60,90}', p_time_zone => 'America/Vancouver');
reset role;
select is(pg_temp.open_thresholds('00000000-0000-4000-8000-000000017432'), array[30, 60, 90],
  'a new time zone refreshes the clinic''s products');

-- A read-only clinic changes nothing.
update public.clinics set subscription_status = 'read_only' where id = '00000000-0000-4000-8000-000000017411';
select pg_temp.act_as('00000000-0000-4000-8000-000000017401');
select throws_ok($$select pg_temp.save('Smile Dental', '{90}')$$, '42501',
  'The clinic is read-only until a payment method is added', 'a read-only clinic keeps its settings');
reset role;

select * from finish();
rollback;
