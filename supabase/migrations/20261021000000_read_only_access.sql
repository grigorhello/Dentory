-- MS-142 follow-up (its review's notes): in a read-only clinic an admin can still take someone off the team, since
-- removing access must not wait for billing, and the logos bucket refuses a new or replaced logo as the tables refuse
-- writes. Inviting, changing a role and resending an invitation still need a payment method (team_target).

-- Remove from clinic, or revoke an invitation, read-only clinics included. Security definer, so the read-only trigger
-- on memberships (MS-142) lets the admin's change through; the admin and last-admin checks stay, and a membership of a
-- clinic the caller is not in is not found, as under RLS before.
create or replace function public.team_remove(p_membership_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member public.memberships;
begin
  select * into v_member from public.memberships m
  where m.id = p_membership_id and m.status in ('active', 'invited') and coalesce(public.is_member(m.clinic_id), false);
  if v_member.id is null then
    raise exception 'This person is no longer on the team.' using errcode = '22023';
  end if;
  if not coalesce(public.is_admin(v_member.clinic_id), false) then
    raise exception 'Only an admin can change the team' using errcode = '42501';
  end if;
  update public.memberships
  set status = 'revoked', invite_token_hash = null, invite_expires_at = null
  where id = v_member.id;
exception
  when restrict_violation then
    raise exception 'A clinic needs at least one admin.' using errcode = '22023';
end;
$$;

-- The clinic's logo is written only while the clinic may write, as Clinic settings' Save already requires.
drop policy logos_admin_write on storage.objects;
create policy logos_admin_write on storage.objects for insert to authenticated
  with check (
    bucket_id = 'logos'
    and public.is_admin((storage.foldername(name))[1]::uuid)
    and coalesce(public.clinic_can_write((storage.foldername(name))[1]::uuid), false)
  );
drop policy logos_admin_update on storage.objects;
create policy logos_admin_update on storage.objects for update to authenticated
  using (bucket_id = 'logos' and public.is_admin((storage.foldername(name))[1]::uuid))
  with check (
    bucket_id = 'logos'
    and public.is_admin((storage.foldername(name))[1]::uuid)
    and coalesce(public.clinic_can_write((storage.foldername(name))[1]::uuid), false)
  );
