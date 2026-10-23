-- MS-138 · Team (PRD §6.9, Appendix B `team`, Appendix C `invite`; f31 Admin, f32 Staff). The list for every member,
-- and the admin's role changes and removals. Inviting and resending go through the invite_member Edge Function
-- (MS-112), which creates or refreshes the invited row.
--
-- Removing a member keeps their row as revoked, so their name stays on the history they wrote and an invitation can
-- bring them back; revoking an invitation does the same to the invited row and its link stops working. Either way the
-- person loses access at once: every policy asks `is_member`, which counts active rows only. The last active admin can
-- be neither demoted nor removed (`memberships_keep_an_admin`); an admin may step down or leave while another remains.

-- Admins first, then Staff, then the invitations still open; each group in the order people joined or were invited.
create function public.team_members(p_clinic_id uuid)
returns table (
  id uuid,
  user_id uuid,
  full_name text,
  email text,
  role public.membership_role,
  status public.membership_status,
  invited_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select m.id, m.user_id, coalesce(nullif(p.full_name, ''), m.full_name), m.email, m.role, m.status, m.invited_at
  from public.memberships m
  left join public.profiles p on p.user_id = m.user_id
  where m.clinic_id = p_clinic_id and m.status in ('active', 'invited')
  order by m.status = 'invited', m.role = 'staff', m.invited_at, m.id;
$$;
revoke execute on function public.team_members(uuid) from public, anon;
grant execute on function public.team_members(uuid) to authenticated, service_role;

-- The membership an admin may change: in their clinic, still active or invited. Refusals carry the sentence the app
-- shows.
create function public.team_target(p_membership_id uuid)
returns public.memberships
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_member public.memberships;
begin
  select * into v_member from public.memberships m
  where m.id = p_membership_id and m.status in ('active', 'invited');
  if v_member.id is null then
    raise exception 'This person is no longer on the team.' using errcode = '22023';
  end if;
  if not public.is_admin(v_member.clinic_id) then
    raise exception 'Only an admin can change the team' using errcode = '42501';
  end if;
  if not coalesce(public.clinic_can_write(v_member.clinic_id), false) then
    raise exception 'The clinic is read-only until a payment method is added' using errcode = '42501';
  end if;
  return v_member;
end;
$$;
revoke execute on function public.team_target(uuid) from public, anon;
grant execute on function public.team_target(uuid) to authenticated, service_role;

create function public.team_set_role(p_membership_id uuid, p_role public.membership_role)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_member public.memberships := public.team_target(p_membership_id);
begin
  update public.memberships set role = p_role where id = v_member.id;
exception
  when restrict_violation then
    raise exception 'A clinic needs at least one admin.' using errcode = '22023';
end;
$$;
revoke execute on function public.team_set_role(uuid, public.membership_role) from public, anon;
grant execute on function public.team_set_role(uuid, public.membership_role) to authenticated, service_role;

-- Remove from clinic, or revoke an invitation: the row becomes revoked and an invitation's link stops working.
create function public.team_remove(p_membership_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_member public.memberships := public.team_target(p_membership_id);
begin
  update public.memberships
  set status = 'revoked', invite_token_hash = null, invite_expires_at = null
  where id = v_member.id;
exception
  when restrict_violation then
    raise exception 'A clinic needs at least one admin.' using errcode = '22023';
end;
$$;
revoke execute on function public.team_remove(uuid) from public, anon;
grant execute on function public.team_remove(uuid) to authenticated, service_role;
