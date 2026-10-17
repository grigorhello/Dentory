-- MS-111 · Admin sign-up: create the clinic with its admin membership and default categories, and
-- record the team invitations (PRD §6.1; MS-100 D13, D14). The invitation email and token arrive with
-- MS-112; this migration only creates the rows.

-- The clinic currency follows the country (MS-100 D14): no currency question at sign-up.
create function public.currency_for_country(p_country char(2))
returns char(3)
language sql
immutable
set search_path = ''
as $$
  select case upper(p_country)
    when 'CA' then 'CAD' when 'US' then 'USD' when 'GB' then 'GBP' when 'AU' then 'AUD' when 'NZ' then 'NZD'
    when 'CH' then 'CHF' when 'SE' then 'SEK' when 'NO' then 'NOK' when 'DK' then 'DKK' when 'PL' then 'PLN'
    when 'CZ' then 'CZK' when 'HU' then 'HUF' when 'RO' then 'RON' when 'JP' then 'JPY' when 'MX' then 'MXN'
    when 'BR' then 'BRL' when 'IN' then 'INR' when 'ZA' then 'ZAR' when 'AE' then 'AED' when 'SG' then 'SGD'
    when 'HK' then 'HKD' when 'IL' then 'ILS' when 'AM' then 'AMD' when 'GE' then 'GEL' when 'TR' then 'TRY'
    when 'KR' then 'KRW' when 'CN' then 'CNY'
    when 'AT' then 'EUR' when 'BE' then 'EUR' when 'CY' then 'EUR' when 'DE' then 'EUR' when 'EE' then 'EUR'
    when 'ES' then 'EUR' when 'FI' then 'EUR' when 'FR' then 'EUR' when 'GR' then 'EUR' when 'HR' then 'EUR'
    when 'IE' then 'EUR' when 'IT' then 'EUR' when 'LT' then 'EUR' when 'LU' then 'EUR' when 'LV' then 'EUR'
    when 'MT' then 'EUR' when 'NL' then 'EUR' when 'PT' then 'EUR' when 'SI' then 'EUR' when 'SK' then 'EUR'
    else 'USD'
  end::char(3);
$$;
grant execute on function public.currency_for_country(char(2)) to authenticated, service_role;

-- Where the caller stands: 'active' (a member of a clinic), 'none' (never belonged to one: admin sign-up
-- continues at the clinic step), or the status of their latest non-active row ('revoked', 'invited'), which
-- signs them out. Security definer, because the memberships policy only shows rows of clinics one belongs to.
create function public.membership_state()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select 'active' from public.memberships where user_id = auth.uid() and status = 'active' limit 1),
    (select status::text from public.memberships where user_id = auth.uid() order by created_at desc limit 1),
    'none'
  );
$$;
grant execute on function public.membership_state() to authenticated, service_role;

-- Creates the signed-in user's clinic: the clinic row, the admin membership, the user's profile and the
-- ten default categories (D13), in one transaction. Idempotent: a user who already belongs to a clinic
-- gets that clinic back, so a relaunch after step 2 never creates a second one. Clinics have no insert
-- policy; this is the only way one is made.
create function public.clinic_create(
  p_name text,
  p_city text,
  p_country char(2),
  p_time_zone text,
  p_full_name text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_email text;
  v_clinic uuid;
  v_name text := btrim(coalesce(p_name, ''));
  v_country char(2) := upper(btrim(coalesce(p_country, '')));
begin
  if v_user is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select clinic_id into v_clinic from public.memberships
  where user_id = v_user and status = 'active' order by created_at limit 1;
  if v_clinic is not null then
    return v_clinic;
  end if;
  if exists (select 1 from public.memberships where user_id = v_user) then
    -- Revoked or invited elsewhere: not a new clinic owner.
    raise exception 'This account belongs to another clinic' using errcode = '42501';
  end if;
  if length(v_name) < 1 or length(v_name) > 120 then
    raise exception 'Enter the clinic name' using errcode = '22023';
  end if;
  if v_country !~ '^[A-Z]{2}$' then
    raise exception 'Choose a country' using errcode = '22023';
  end if;
  if p_time_zone is null or p_time_zone !~ '^[A-Za-z_+\-/0-9]{1,64}$' then
    raise exception 'Unknown time zone' using errcode = '22023';
  end if;
  select email into v_email from auth.users where id = v_user;

  insert into public.profiles (user_id, full_name)
  values (v_user, btrim(coalesce(p_full_name, '')))
  on conflict (user_id) do update set full_name = excluded.full_name where excluded.full_name <> '';

  insert into public.clinics (name, city, country, currency, time_zone)
  values (v_name, nullif(btrim(coalesce(p_city, '')), ''), v_country, public.currency_for_country(v_country), p_time_zone)
  returning id into v_clinic;

  insert into public.memberships (clinic_id, user_id, email, full_name, role, status, invited_by)
  values (v_clinic, v_user, coalesce(v_email, ''), btrim(coalesce(p_full_name, '')), 'admin', 'active', null);

  insert into public.categories (clinic_id, name, position)
  select v_clinic, c.name, c.position
  from unnest(array['Anesthetic', 'Restorative', 'Endodontics', 'Impression', 'Preventive', 'Surgical',
                    'PPE', 'Sterilization', 'Disposable', 'Other']) with ordinality as c (name, position);
  return v_clinic;
end;
$$;
grant execute on function public.clinic_create(text, text, char(2), text, text) to authenticated, service_role;

-- Records invitations for the team (step 3 and, later, Team): one invited membership per address.
-- p_invites is [{"email": "...", "role": "staff" | "admin"}]. Addresses that already belong to the clinic
-- are left alone; invited ones get a fresh 7-day window. Returns how many rows were created or refreshed.
-- MS-112 adds the token and the email on top of these rows.
create function public.invite_members(p_clinic_id uuid, p_invites jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row record;
  v_count integer := 0;
  v_email text;
  v_role public.membership_role;
begin
  if not coalesce(public.is_admin(p_clinic_id), false) then
    raise exception 'Only an admin can invite' using errcode = '42501';
  end if;
  if not coalesce(public.clinic_can_write(p_clinic_id), false) then
    raise exception 'The clinic is read-only until a payment method is added' using errcode = '42501';
  end if;
  if p_invites is null or jsonb_typeof(p_invites) <> 'array' then
    raise exception 'Invitations must be a list' using errcode = '22023';
  end if;
  for v_row in select * from jsonb_to_recordset(p_invites) as x (email text, role text) loop
    v_email := lower(btrim(coalesce(v_row.email, '')));
    if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
      raise exception 'Enter a valid email' using errcode = '22023';
    end if;
    if coalesce(v_row.role, 'staff') not in ('staff', 'admin') then
      raise exception 'Role must be Staff or Admin' using errcode = '22023';
    end if;
    v_role := coalesce(v_row.role, 'staff')::public.membership_role;
    if exists (select 1 from public.memberships m
               where m.clinic_id = p_clinic_id and lower(m.email) = v_email and m.status = 'active') then
      continue;
    end if;
    insert into public.memberships (clinic_id, email, role, status, invited_by, invited_at, invite_expires_at)
    values (p_clinic_id, v_email, v_role, 'invited', auth.uid(), now(), now() + interval '7 days')
    on conflict (clinic_id, lower(email)) do update
      set role = excluded.role, status = 'invited', invited_by = excluded.invited_by,
          invited_at = now(), invite_expires_at = now() + interval '7 days',
          invite_token_hash = null
      where public.memberships.status <> 'active';
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
grant execute on function public.invite_members(uuid, jsonb) to authenticated, service_role;
