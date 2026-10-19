-- MS-122 · Procedures list and history (PRD §6.3, f11, f12).
-- Two reads for the Procedures tab, both security invoker so RLS keeps each clinic to itself:
-- the templates with their item counts and shortages, and the past procedures, newest first, a page at a time.

-- One row per active template in creation order: how many supplies it lists (archived products left out), how
-- many of them stock cannot cover at their default quantity ("1 not available"), and how many it would use
-- up exactly ("2 will run out"). A multi-use product is compared on its unopened stock; a default of 0 (the
-- open one is used) never counts as short.
create function public.procedure_templates_list(p_clinic_id uuid)
returns table (
  id uuid,
  name text,
  item_count integer,
  not_available_count integer,
  run_out_count integer
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    t.id,
    t.name,
    count(p.id)::integer,
    (count(p.id) filter (where i.default_qty > 0 and s.unopened < i.default_qty))::integer,
    (count(p.id) filter (where i.default_qty > 0 and s.unopened = i.default_qty))::integer
  from public.procedure_templates t
  left join public.procedure_template_items i on i.template_id = t.id
  left join public.products p on p.id = i.product_id and p.archived_at is null
  left join public.product_stock s on s.product_id = p.id
  where t.clinic_id = p_clinic_id and t.archived_at is null
  group by t.id, t.name, t.created_at
  order by t.created_at, lower(t.name), t.id;
$$;
revoke execute on function public.procedure_templates_list(uuid) from public, anon;
grant execute on function public.procedure_templates_list(uuid) to authenticated, service_role;

-- Past procedures, newest first, cancelled ones included: name, when, who (the member's full name, empty when
-- the membership is gone), how many supplies were recorded, and when it was cancelled. A page continues after
-- the previous page's last row, named by its id (`p_after_id`): the server looks up that row's exact time, so
-- a procedure started meanwhile neither repeats nor hides a row, even one started in the same second. (A time
-- sent by the app would come back rounded to the second and skip such rows.)
create function public.procedure_history(p_clinic_id uuid, p_after_id uuid default null, p_limit integer default 30)
returns table (
  id uuid,
  name text,
  started_at timestamptz,
  started_by_name text,
  item_count integer,
  cancelled_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    e.id,
    e.name,
    e.started_at,
    coalesce(m.full_name, ''),
    (select count(*) from public.procedure_event_items i where i.event_id = e.id)::integer,
    e.cancelled_at
  from public.procedure_events e
  left join public.memberships m on m.clinic_id = e.clinic_id and m.user_id = e.started_by
  where e.clinic_id = p_clinic_id
    and (p_after_id is null
      or (e.started_at, e.id) < (
        select c.started_at, c.id from public.procedure_events c where c.id = p_after_id and c.clinic_id = p_clinic_id
      ))
  order by e.started_at desc, e.id desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;
revoke execute on function public.procedure_history(uuid, uuid, integer) from public, anon;
grant execute on function public.procedure_history(uuid, uuid, integer) to authenticated, service_role;
