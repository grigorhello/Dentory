-- MS-134 · Activity: history (PRD §6.8 History, §9 Audit; Appendix B `activity`; f9). A read of the ledger, newest
-- first, a page at a time, for Admin and Staff. Security invoker: a member sees only their clinic. Nothing here writes.

-- One row per ledger row, except that when the whole clinic is listed a procedure's rows come as one row per action:
-- the start, each edit and the cancellation, under the procedure's name with the sum of their deltas ("Root canal",
-- -6). Filtered to one product (Product detail's Show all), every row is that product's own.
-- p_filter: null for All, or 'receiving', 'procedures' (cancellations included), 'counts', 'adjustments' (disposals,
-- bottles opened and finished included). An Undo keeps its original's type, so it shows under the same filter.
-- A page continues after the previous page's last row, named by its id (`p_after_id`, a ledger row's or a grouped
-- action's): the server looks up that row's time, so rows written in the same instant neither repeat nor hide.
create function public.activity_history(
  p_clinic_id uuid,
  p_filter text default null,
  p_product_id uuid default null,
  p_after_id uuid default null,
  p_limit integer default 50
)
returns table (
  id uuid,
  at timestamptz,
  type public.transaction_type,
  subject text,
  product_id uuid,
  delta numeric,
  qty_before numeric,
  qty_after numeric,
  ref_type public.transaction_ref_type,
  ref_label text,
  reason text,
  note text,
  is_edit boolean,
  by_name text
)
language sql
stable
security invoker
set search_path = ''
as $$
  with filtered as (
    select t.*, p.name as product_name,
           p_product_id is null and t.type in ('procedure', 'cancellation') and t.ref_type = 'procedure_event'
             as grouped
    from public.transactions t
    join public.products p on p.id = t.product_id
    where t.clinic_id = p_clinic_id
      and (p_product_id is null or t.product_id = p_product_id)
      and case p_filter
        when 'receiving' then t.type = 'receiving'
        when 'procedures' then t.type in ('procedure', 'cancellation')
        when 'counts' then t.type = 'count'
        when 'adjustments' then t.type in ('adjustment', 'disposal')
        else true
      end
  ),
  listed as (
    select f.action_id as id, min(f.at) as at, min(f.type::text)::public.transaction_type as type,
           min(e.name) as subject, null::uuid as product_id, sum(f.delta) as delta,
           null::numeric as qty_before, null::numeric as qty_after,
           'procedure_event'::public.transaction_ref_type as ref_type, min(e.name) as ref_label,
           null::text as reason, max(f.note) as note,
           bool_and(f.type = 'procedure' and f.action_id <> f.ref_id) as is_edit,
           min(f.by_user::text)::uuid as by_user
    from filtered f
    join public.procedure_events e on e.id = f.ref_id
    where f.grouped
    group by f.action_id
    union all
    select f.id, f.at, f.type, f.product_name, f.product_id, f.delta, f.qty_before, f.qty_after,
           f.ref_type, f.ref_label, f.reason, f.note, false, f.by_user
    from filtered f
    where not f.grouped
  ),
  after_row as (
    select coalesce(
      (select t.at from public.transactions t where t.id = p_after_id and t.clinic_id = p_clinic_id),
      (select min(t.at) from public.transactions t where t.action_id = p_after_id and t.clinic_id = p_clinic_id)
    ) as at
  )
  select l.id, l.at, l.type, l.subject, l.product_id, l.delta, l.qty_before, l.qty_after, l.ref_type, l.ref_label,
         l.reason, l.note, l.is_edit, coalesce(m.full_name, '')
  from listed l
  left join public.memberships m on m.clinic_id = p_clinic_id and m.user_id = l.by_user
  where p_after_id is null or (l.at, l.id) < ((select a.at from after_row a), p_after_id)
  order by l.at desc, l.id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;
revoke execute on function public.activity_history(uuid, text, uuid, uuid, integer) from public, anon;
grant execute on function public.activity_history(uuid, text, uuid, uuid, integer) to authenticated, service_role;
