-- MS-150 · After `make perf-concurrency`'s run (concurrency.sh): every change the clients made was written whole and
-- every product's stock still equals its ledger. `since` is when the run began, `expected` how many changes it made.
-- Stops with the reason when anything is missing; else prints what the run wrote.

create temp table perf_run as select :'since'::timestamptz as since, :expected::integer as expected;

do $$
declare
  c constant uuid := '10ad0000-0000-4000-8000-000000000001';
  v_since timestamptz;
  v_expected integer;
  v_changes integer;
  v_wrong text;
begin
  select since, expected into v_since, v_expected from perf_run;

  -- Every change the clients made committed: one action each, none lost to a deadlock or a failure.
  select count(*) into v_changes
  from public.stock_actions a
  where a.clinic_id = c and a.created_at >= v_since and a.kind in ('procedure_start', 'bottle_open');
  if v_changes <> v_expected then
    raise exception 'The run made % changes, but % were written', v_expected, v_changes;
  end if;

  -- Every procedure has a line per supply of its template and a bottle per multi-use one.
  select string_agg(e.id::text, ', ') into v_wrong
  from public.procedure_events e
  where e.clinic_id = c and e.started_at >= v_since
    and (
      (select count(*) from public.procedure_event_items i where i.event_id = e.id)
        <> (select count(*) from public.procedure_template_items t where t.template_id = e.template_id)
      or (select count(*) from public.procedure_event_openings o where o.event_id = e.id)
        <> (select count(*) from public.procedure_template_items t
            join public.products p on p.id = t.product_id
            where t.template_id = e.template_id and p.tracking = 'multi_use')
    );
  if v_wrong is not null then
    raise exception 'These procedures were written in part: %', v_wrong;
  end if;

  -- Every bottle opened, from a procedure or from its page, is an open item.
  if (select count(*) from public.open_items o where o.clinic_id = c and o.opened_at >= v_since)
     <> (select count(*) from public.procedure_event_openings o
         join public.procedure_events e on e.id = o.event_id
         where e.clinic_id = c and e.started_at >= v_since)
      + (select count(*) from public.stock_actions a
         where a.clinic_id = c and a.created_at >= v_since and a.kind = 'bottle_open')
  then
    raise exception 'The bottles opened and the open items written differ';
  end if;

  -- No lost update: every product's batches and open bottles add up to its ledger, as the load seed left them.
  select string_agg(p.name, ', ') into v_wrong
  from public.products p
  join public.product_stock s on s.product_id = p.id
  where p.clinic_id = c
    and s.quantity <> (select coalesce(sum(t.delta), 0) from public.transactions t where t.product_id = p.id);
  if v_wrong is not null then
    raise exception 'The ledger does not end at the stock for: %', v_wrong;
  end if;
end;
$$;

\echo
\echo 'Load test dental after the run: every change written, every product''s stock equal to its ledger'
select
  count(*) filter (where a.kind = 'procedure_start') as "Procedures started",
  count(*) filter (where a.kind = 'bottle_open') as "Bottles opened from a product",
  (select count(*) from public.open_items o, perf_run r
   where o.clinic_id = '10ad0000-0000-4000-8000-000000000001' and o.opened_at >= r.since) as "Bottles opened in all",
  (select count(*) from public.transactions t, perf_run r
   where t.clinic_id = '10ad0000-0000-4000-8000-000000000001' and t.created_at >= r.since) as "Ledger rows written"
from public.stock_actions a, perf_run r
where a.clinic_id = '10ad0000-0000-4000-8000-000000000001' and a.created_at >= r.since;
