-- MS-112 · Invitations: a random token per invited membership (only its SHA-256 hash is stored), the public
-- lookup behind the Join screen (f5) and the accept step that turns the invited row into an active member
-- (PRD §6.1; MS-100 G4, D12). The Edge Functions invite_member and accept_invitation are the only callers of
-- invitation_create, auth_user_id_for_email, invitation_check and invitation_accept (service_role): the raw token travels in
-- the email alone, never back to the admin's app. invitation_lookup is open to the signed-out app, because
-- the Join screen opens before the invitee has an account; the token is the credential.

-- invite_members (MS-111) recorded invited rows without a token. invitation_create replaces it.
drop function public.invite_members(uuid, jsonb);

-- How a member is named to others: the profile name, else the membership name, else the address.
create function public.member_display_name(p_clinic_id uuid, p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    nullif(p.full_name, ''),
    nullif(m.full_name, ''),
    nullif(m.email, ''),
    'Your admin'
  )
  from public.memberships m
  left join public.profiles p on p.user_id = m.user_id
  where m.clinic_id = p_clinic_id and m.user_id = p_user_id
  limit 1;
$$;

-- Creates or refreshes the invited membership for one address and returns the one-time token with what
-- the email needs. A second call for the same address is the resend: a new token, the old one stops
-- working, the role follows the new call and a blank name keeps the stored one.
create function public.invitation_create(
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

  return query
    select v_id, v_token, c.name, public.member_display_name(p_clinic_id, p_invited_by), v_role::text, v_expires
    from public.clinics c
    where c.id = p_clinic_id;
end;
$$;

-- What the Join screen shows: no rows when the token is unknown, already used or older than 7 days.
create function public.invitation_lookup(p_token text)
returns table (
  clinic_name text,
  invited_by_name text,
  member_role text,
  email text,
  full_name text,
  expires_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.name,
         coalesce(public.member_display_name(m.clinic_id, m.invited_by), 'Your admin'),
         m.role::text,
         m.email,
         m.full_name,
         m.invite_expires_at
  from public.memberships m
  join public.clinics c on c.id = m.clinic_id
  where m.status = 'invited'
    and m.invite_token_hash is not null
    and p_token is not null
    and length(p_token) between 20 and 200
    and m.invite_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
    and m.invite_expires_at > now()
  limit 1;
$$;

-- The auth user behind an address, if one exists: accept_invitation sets that user's password instead
-- of creating a second account.
create function public.auth_user_id_for_email(p_email text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.id
  from auth.users u
  where lower(u.email) = lower(btrim(coalesce(p_email, ''))) and u.deleted_at is null
  limit 1;
$$;

-- Whether p_user_id may take the invitation behind p_token: the clinic id when yes, the refusal as an
-- error otherwise. accept_invitation asks before it touches an existing account's password, and
-- invitation_accept asks again under its row lock, so a refused invitation changes nothing.
create function public.invitation_check(p_token text, p_user_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_row public.memberships%rowtype;
  v_email text;
begin
  if p_user_id is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select m.* into v_row
  from public.memberships m
  where m.status = 'invited'
    and m.invite_token_hash is not null
    and p_token is not null
    and length(p_token) between 20 and 200
    and m.invite_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
  if v_row.id is null or v_row.invite_expires_at is null or v_row.invite_expires_at <= now() then
    raise exception 'This invitation has expired. Ask your admin to resend.' using errcode = '22023';
  end if;
  select lower(u.email) into v_email from auth.users u where u.id = p_user_id and u.deleted_at is null;
  if v_email is null or v_email <> lower(v_row.email) then
    raise exception 'This invitation was sent to another address' using errcode = '42501';
  end if;
  if exists (
    select 1 from public.memberships m
    where m.user_id = p_user_id and m.status = 'active' and m.clinic_id <> v_row.clinic_id
  ) then
    raise exception 'This account belongs to another clinic' using errcode = '42501';
  end if;
  if exists (
    select 1 from public.memberships m
    where m.user_id = p_user_id and m.clinic_id = v_row.clinic_id and m.id <> v_row.id
  ) then
    raise exception 'This account is already on the team' using errcode = '23505';
  end if;
  return v_row.clinic_id;
end;
$$;

-- Turns the invited row into the active membership of p_user_id (whose address must be the invited one),
-- consumes the token and records the name on the profile. Returns the clinic id.
create function public.invitation_accept(p_token text, p_user_id uuid, p_full_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.memberships%rowtype;
  v_name text := btrim(coalesce(p_full_name, ''));
  v_clinic uuid;
begin
  if length(v_name) > 120 then
    raise exception 'The name is too long' using errcode = '22023';
  end if;
  -- Lock the row first, so two accepts of one token cannot both pass the check.
  select m.* into v_row
  from public.memberships m
  where m.status = 'invited'
    and m.invite_token_hash is not null
    and p_token is not null
    and length(p_token) between 20 and 200
    and m.invite_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  for update;
  v_clinic := public.invitation_check(p_token, p_user_id);

  update public.memberships
  set user_id = p_user_id,
      status = 'active',
      full_name = case when v_name <> '' then v_name else full_name end,
      invite_token_hash = null,
      invite_expires_at = null
  where id = v_row.id;

  insert into public.profiles (user_id, full_name)
  values (p_user_id, case when v_name <> '' then v_name else v_row.full_name end)
  on conflict (user_id) do update set full_name = excluded.full_name where excluded.full_name <> '';

  return v_clinic;
end;
$$;

revoke execute on function
  public.invitation_create(uuid, text, text, text, uuid),
  public.member_display_name(uuid, uuid),
  public.auth_user_id_for_email(text),
  public.invitation_check(text, uuid),
  public.invitation_accept(text, uuid, text)
  from public, anon, authenticated;
grant execute on function
  public.invitation_create(uuid, text, text, text, uuid),
  public.member_display_name(uuid, uuid),
  public.auth_user_id_for_email(text),
  public.invitation_check(text, uuid),
  public.invitation_accept(text, uuid, text)
  to service_role;

revoke execute on function public.invitation_lookup(text) from public;
grant execute on function public.invitation_lookup(text) to anon, authenticated, service_role;
