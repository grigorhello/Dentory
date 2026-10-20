-- MS-139 · Clinic settings (PRD §6.9, f33, MS-100 D8 and D14). The admin edits the clinic's name, city, country,
-- currency, time zone, expiry warning and weekly email digest; the logo goes to Storage as at sign-up (MS-111).
-- Changing the expiry warning or the time zone moves every batch's expiry status and alert at once, so Inventory,
-- Expiring soon and Home's counts follow without waiting for the nightly refresh.

-- Saves the settings in one go, refusing with the sentence and the field the app shows. A new expiry warning or time
-- zone then re-evaluates every product of the clinic, as the nightly refresh would: its status, its expiring alerts
-- (one per threshold still chosen, the others closed) and its To buy line. Security definer for that refresh, so
-- the admin and read-only checks the clinics policy makes are made here.
create function public.clinic_settings_save(
  p_clinic_id uuid,
  p_name text,
  p_city text,
  p_country text,
  p_currency text,
  p_time_zone text,
  p_expiry_thresholds integer[],
  p_email_digest boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_country text := upper(btrim(coalesce(p_country, '')));
  v_currency text := upper(btrim(coalesce(p_currency, '')));
  v_before public.clinics;
begin
  if not coalesce(public.is_admin(p_clinic_id), false) then
    raise exception 'Only an admin can change clinic settings' using errcode = '42501';
  end if;
  if not coalesce(public.clinic_can_write(p_clinic_id), false) then
    raise exception 'The clinic is read-only until a payment method is added' using errcode = '42501';
  end if;
  if length(v_name) < 1 or length(v_name) > 120 then
    raise exception 'Enter the clinic name' using errcode = '22023', hint = 'name';
  end if;
  if v_country !~ '^[A-Z]{2}$' then
    raise exception 'Choose a country' using errcode = '22023', hint = 'country';
  end if;
  if v_currency !~ '^[A-Z]{3}$' then
    raise exception 'Choose a currency' using errcode = '22023', hint = 'currency';
  end if;
  if p_time_zone is null or not exists (select 1 from pg_catalog.pg_timezone_names z where z.name = p_time_zone) then
    raise exception 'Choose a time zone' using errcode = '22023', hint = 'timeZone';
  end if;
  if p_expiry_thresholds is null
     or p_expiry_thresholds not in ('{30,60,90}'::integer[], '{60,90}'::integer[], '{90}'::integer[]) then
    raise exception 'Choose an expiry warning' using errcode = '22023', hint = 'expiryWarning';
  end if;

  select * into v_before from public.clinics where id = p_clinic_id;
  update public.clinics
  set name = v_name,
      city = nullif(btrim(coalesce(p_city, '')), ''),
      country = v_country,
      currency = v_currency,
      time_zone = p_time_zone,
      expiry_thresholds = p_expiry_thresholds,
      email_digest = coalesce(p_email_digest, email_digest)
  where id = p_clinic_id;

  if v_before.expiry_thresholds is distinct from p_expiry_thresholds
     or v_before.time_zone is distinct from p_time_zone then
    perform public.refresh_product(p.id)
    from public.products p
    where p.clinic_id = p_clinic_id and p.archived_at is null;
  end if;
end;
$$;
revoke execute on function public.clinic_settings_save(uuid, text, text, text, text, text, integer[], boolean)
  from public, anon;
grant execute on function public.clinic_settings_save(uuid, text, text, text, text, text, integer[], boolean)
  to authenticated, service_role;
