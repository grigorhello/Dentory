-- MS-151 · Security review before launch: what the review closed in the database (docs/security/security-review.md,
-- findings F1, F2, F5, F6 and F8). 46_security_invariants_test.sql keeps the rules that hold for every table and
-- function from now on; 47_security_review_test.sql checks these fixes.

-- F1 · Memberships change only through the functions that check what they write ----------------------------------
-- MS-105 let an admin insert, update and delete memberships directly, every column. accept_invitation (MS-112) takes
-- an invited row's token hash as proof that the invitation reached the address, so an admin who wrote a row with the
-- hash of a token of their own, or turned a colleague's row back into an invitation, could use that token to set the
-- password of the account behind the address: a colleague's, or any account not active in another clinic. Every
-- membership is now written by invitation_create and invitation_accept (the Edge Functions, as service_role),
-- clinic_create, team_remove or team_set_role. team_set_role runs as the caller, so the role column stays writable,
-- under memberships_admin_update and the last-admin and read-only triggers, as before.
revoke insert, update, delete on public.memberships from authenticated;
grant update (role) on public.memberships to authenticated;
drop policy memberships_admin_insert on public.memberships;
drop policy memberships_admin_delete on public.memberships;

-- F2 · Clinic settings save through clinic_settings_save, billing emails through billing_emails_save ---------------
-- The MS-105 column grant let an admin write the name, city, country, currency, time zone, expiry warning, digest
-- switch and billing emails directly, past those functions' checks and the product refresh a new warning or time zone
-- needs; a time zone Postgres does not know then stopped the nightly refresh of every clinic (#122, from the MS-139
-- review). The app writes only the logo's path directly (ClinicLogoStorage). Revoking the table's right revokes its
-- columns' too.
revoke update on public.clinics from authenticated;
grant update (logo_path) on public.clinics to authenticated;

-- clinic_create checked only the characters of the time zone sign-up sends (the device's), so a clinic made through
-- the API with a zone Postgres does not know ("Mars/Olympus_Mons") stopped that nightly refresh as soon as one of its
-- products ran out: the out-of-stock push works out the clinic's waking hours in its zone. Such a zone is kept as UTC,
-- which Clinic settings shows and lets the admin change, since no sign-up step asks for the zone. MS-111's function,
-- unchanged but for that.
create or replace function public.clinic_create(
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
  values (
    v_name, nullif(btrim(coalesce(p_city, '')), ''), v_country, public.currency_for_country(v_country),
    coalesce((select z.name from pg_catalog.pg_timezone_names z where z.name = p_time_zone limit 1), 'UTC')
  )
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

-- F5 · Billing stays with the admins -------------------------------------------------------------------------------
-- Members read their clinic's row; its Stripe ids, the lifetime promotion and the billing emails are billing, which
-- the role table keeps to admins (PRD §2) and billing_summary and billing_emails_list give them.
revoke select on public.clinics from authenticated;
grant select (
  id, created_at, name, logo_path, city, country, currency, time_zone, expiry_thresholds, email_digest,
  trial_ends_at, subscription_status
) on public.clinics to authenticated;

-- F6 · At most 30 invitations an hour per clinic, and 3 an hour from it to one address ---------------------------
-- Every invitation, a resend included, is an email from dentory.ca with the clinic's and the inviter's names in it,
-- and anyone can open a clinic. A clinic sends at most 30 in an hour, its whole team twice over, and 3 to one address;
-- an address is counted per clinic, since counting it across clinics would tell one clinic that another had just
-- invited that person. invitation_create records each invitation it makes and forgets it after the hour; nothing else
-- reads the record.
create table public.invitation_sends (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  email text not null,
  sent_at timestamptz not null default now()
);
create index invitation_sends_clinic_idx on public.invitation_sends (clinic_id, sent_at);
alter table public.invitation_sends enable row level security;
revoke all on public.invitation_sends from anon, authenticated;

-- MS-112's function, unchanged but for the two limits and the record of each invitation it makes.
create or replace function public.invitation_create(
  p_clinic_id uuid,
  p_email text,
  p_role text,
  p_full_name text,
  p_invited_by uuid
)
returns table (
  membership_id uuid,
  token text,
  clinic_name text,
  invited_by_name text,
  member_role text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_name text := btrim(coalesce(p_full_name, ''));
  v_role_text text := coalesce(nullif(btrim(p_role), ''), 'staff');
  v_role public.membership_role;
  v_token text;
  v_id uuid;
  v_expires timestamptz := now() + interval '7 days';
begin
  if p_invited_by is null or not exists (
    select 1 from public.memberships m
    where m.clinic_id = p_clinic_id and m.user_id = p_invited_by and m.role = 'admin' and m.status = 'active'
  ) then
    raise exception 'Only an admin can invite' using errcode = '42501';
  end if;
  if not coalesce(public.clinic_can_write(p_clinic_id), false) then
    raise exception 'The clinic is read-only until a payment method is added' using errcode = '42501';
  end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Enter a valid email' using errcode = '22023';
  end if;
  if v_role_text not in ('staff', 'admin') then
    raise exception 'Role must be Staff or Admin' using errcode = '22023';
  end if;
  v_role := v_role_text::public.membership_role;
  if length(v_name) > 120 then
    raise exception 'The name is too long' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.memberships m
    where m.clinic_id = p_clinic_id and lower(m.email) = v_email and m.status = 'active'
  ) then
    raise exception '% is already on the team', v_email using errcode = '23505';
  end if;

  -- One invitation at a time per clinic, so two at once cannot both pass the limits.
  perform pg_advisory_xact_lock(hashtext('invitation_create'), hashtext(p_clinic_id::text));
  delete from public.invitation_sends s where s.clinic_id = p_clinic_id and s.sent_at <= now() - interval '1 hour';
  if (select count(*) from public.invitation_sends s where s.clinic_id = p_clinic_id) >= 30 then
    raise exception 'Your clinic sent 30 invitations in the last hour. Try again in an hour.' using errcode = '22023';
  end if;
  if (select count(*) from public.invitation_sends s where s.clinic_id = p_clinic_id and s.email = v_email) >= 3 then
    raise exception 'This address got 3 invitations in the last hour. Try again in an hour.'
      using errcode = '22023';
  end if;

  -- 32 random bytes as URL-safe base64: the secret that only the email carries.
  v_token := translate(rtrim(encode(extensions.gen_random_bytes(32), 'base64'), '='), '+/', '-_');

  insert into public.memberships (
    clinic_id, email, full_name, role, status, invited_by, invited_at, invite_token_hash, invite_expires_at
  )
  values (
    p_clinic_id, v_email, v_name, v_role, 'invited', p_invited_by, now(),
    encode(extensions.digest(v_token, 'sha256'), 'hex'), v_expires
  )
  on conflict (clinic_id, lower(email)) do update
    set role = excluded.role,
        status = 'invited',
        full_name = case when excluded.full_name <> '' then excluded.full_name else public.memberships.full_name end,
        invited_by = excluded.invited_by,
        invited_at = excluded.invited_at,
        invite_token_hash = excluded.invite_token_hash,
        invite_expires_at = excluded.invite_expires_at
    where public.memberships.status <> 'active'
  returning id into v_id;
  if v_id is null then
    raise exception '% is already on the team', v_email using errcode = '23505';
  end if;
  insert into public.invitation_sends (clinic_id, email) values (p_clinic_id, v_email);

  return query
    select v_id, v_token, c.name, public.member_display_name(p_clinic_id, p_invited_by), v_role::text, v_expires
    from public.clinics c
    where c.id = p_clinic_id;
end;
$$;
revoke execute on function public.invitation_create(uuid, text, text, text, uuid) from public, anon, authenticated;
grant execute on function public.invitation_create(uuid, text, text, text, uuid) to service_role;

-- F8 · The anon key reaches the invitation lookup and nothing else ---------------------------------------------------
-- Postgres lets everyone execute a new function, so six functions the signed-out app never calls were open to the
-- anon key. None gave it anything (clinic_create and membership_state ask for a user, the others compute, or read
-- tables anon cannot), but each was one careless change away. A function made from now on is revoked from public and
-- anon as the later migrations already do, unless the signed-out app needs it, as it needs invitation_lookup:
-- 46_security_invariants_test.sql fails otherwise.
revoke execute on function
  public.clinic_create(text, text, char(2), text, text),
  public.currency_for_country(char(2)),
  public.days_to_expiry(date, text),
  public.evaluate_product_status(public.tracking_mode, numeric, numeric, numeric, numeric, integer, integer),
  public.membership_state(),
  public.product_status_of(uuid)
  from public, anon;
