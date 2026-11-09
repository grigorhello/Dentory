-- `make demo-history-check` (demo-history-check.sh), after the history ran on clinic A: a clinic made the way sign-up
-- makes one, with the general-practice catalog and the test products Pen and Pain killer. Variables: clinic, admin.
-- Stops with the reason when something is off; otherwise prints what the admin's screens read.

create temp table check_args as select :'clinic'::uuid as clinic, :'admin'::uuid as admin;

-- What the admin reads, through the app's own calls and the clinic's policies ----------------------------------------

begin;
select set_config('request.jwt.claims', json_build_object('sub', admin, 'role', 'authenticated')::text, true),
  set_config('check.clinic', clinic::text, true)
from check_args \gset
set local role authenticated;
do $$
declare
  c uuid := current_setting('check.clinic')::uuid;
  v_wrong text;
  v_after uuid;
  v_row record;
  v_rows integer;
  v_damaged integer := 0;
  v_kinds text[] := '{}';
begin
  -- Inventory: the 74 catalog products, Pen and Pain killer gone, each badge as the story ends.
  select string_agg(format('%s reads %s', name, status), '; ' order by name) into v_wrong
  from public.inventory_list(c)
  where status <> case name
      when 'Earloop masks level 3' then 'low'
      when 'Matrix band' then 'low'
      when 'Composite A2' then 'low'
      when 'Fluoride varnish 5%' then 'low'
      when 'Rubber dam latex-free' then 'out_of_stock'
      when 'Collagen plugs' then 'expiring'
      when 'Glass ionomer restorative' then 'expiring'
      when 'Lidocaine 2% 1:100,000' then 'expiring'
      when 'Paper points' then 'missing_expiry'
      else 'healthy'
    end;
  if v_wrong is not null or (select count(*) from public.inventory_list(c)) <> 74 then
    raise exception 'Inventory differs from the story''s end: %', coalesce(v_wrong, 'it does not list the 74 products');
  end if;

  -- Home: the three tiles, a stock value that means something, and the latest procedure, not cancelled.
  if (select (a.to_buy_count, a.expiring_batch_count, a.missing_expiry_product_count)
      from public.clinic_attention a where a.clinic_id = c) <> (3, 3, 1)
     or (select a.inventory_value from public.clinic_attention a where a.clinic_id = c) < 3000
     or (select a.value_at_risk_90 from public.clinic_attention a where a.clinic_id = c) <= 0
  then
    raise exception 'Home does not read 3 To buy, 3 Expiring soon, 1 Missing expiry with a stock value and value at risk';
  end if;
  if (select e.cancelled_at from public.procedure_events e where e.clinic_id = c order by e.started_at desc limit 1)
     is not null
  then
    raise exception 'The latest procedure is the cancelled one';
  end if;

  -- To buy: three lines to buy, two ordered, and the history's received lines.
  select string_agg(t.status || ' ' || t.name, ', ' order by t.status, t.name) into v_wrong
  from public.to_buy_list(c) t where t.status <> 'received';
  if v_wrong is distinct from 'ordered Earloop masks level 3, ordered Matrix band, to_buy Composite A2, '
       'to_buy Fluoride varnish 5%, to_buy Rubber dam latex-free'
     or (select count(*) from public.to_buy_list(c) t where t.status = 'received') < 30
  then
    raise exception 'To buy differs from the story''s end: %', v_wrong;
  end if;

  -- Expiring soon: the three short-dated batches, each with stock and a value.
  select string_agg(b ->> 'name', ', ' order by b ->> 'name') into v_wrong
  from jsonb_array_elements(public.expiring_batches(c) -> 'batches') b
  where (b ->> 'qty')::numeric > 0 and (b ->> 'value')::numeric > 0;
  if v_wrong is distinct from 'Collagen plugs, Glass ionomer restorative, Lidocaine 2% 1:100,000'
     or jsonb_array_length(public.expiring_batches(c) -> 'batches') <> 3
  then
    raise exception 'Expiring soon differs from the story''s end: %', v_wrong;
  end if;

  -- Activity, Alerts: one row per subject, as the end state has them.
  select string_agg(a ->> 'kind' || ' ' || (a ->> 'name'), ', ' order by a ->> 'kind', a ->> 'name') into v_wrong
  from jsonb_array_elements(public.activity_alerts(c)) a;
  if v_wrong is distinct from 'expiring Collagen plugs, expiring Glass ionomer restorative, '
       'expiring Lidocaine 2% 1:100,000, low Composite A2, low Earloop masks level 3, low Fluoride varnish 5%, '
       'low Matrix band, missing_expiry Paper points, out_of_stock Rubber dam latex-free'
  then
    raise exception 'Activity''s Alerts differ from the story''s end: %', v_wrong;
  end if;

  -- Activity, History, scrolled to its end a page at a time as the app does: deliveries, procedures, Edit usage, the
  -- cancel, counts, bottles, the two write-offs and the disposal.
  loop
    v_rows := 0;
    for v_row in select * from public.activity_history(c, null, null, v_after, 100) loop
      v_rows := v_rows + 1;
      v_after := v_row.id;
      v_kinds := v_kinds || case
          when v_row.is_edit then 'edit'
          when v_row.ref_label in ('Opened a new bottle', 'Finished') then v_row.ref_label
          else v_row.type::text
        end;
      if v_row.reason = 'Damaged' then v_damaged := v_damaged + 1; end if;
    end loop;
    exit when v_rows = 0;
  end loop;
  select string_agg(k, ', ' order by k) into v_wrong
  from unnest(array['receiving', 'procedure', 'edit', 'cancellation', 'count', 'adjustment', 'disposal',
    'Opened a new bottle', 'Finished']) k
  where not k = any (v_kinds);
  if v_wrong is not null or v_damaged <> 2 then
    raise exception 'Activity''s History lacks rows the story writes (%), or does not hold the two write-offs',
      coalesce(v_wrong, 'every kind is there');
  end if;

  -- Procedures: the eight templates in the order they were made, Root canal short of rubber dam; a history of each
  -- working day's procedures with one cancelled.
  select string_agg(t.name, ', ' order by t.ord) into v_wrong
  from public.procedure_templates_list(c) with ordinality t (id, name, item_count, not_available_count, run_out_count, ord);
  if v_wrong is distinct from 'Recall cleaning, Composite filling, Glass ionomer filling, Extraction, Root canal, '
       'Crown preparation, Crown cementation, Emergency exam'
     or (select t.not_available_count from public.procedure_templates_list(c) t where t.name = 'Root canal') <> 1
  then
    raise exception 'The Procedures list differs from the story''s: %', v_wrong;
  end if;
  if (select count(*) from public.procedure_events e where e.clinic_id = c) < 300
     or (select count(*) from public.procedure_events e where e.clinic_id = c and e.cancelled_at is not null) <> 1
  then
    raise exception 'The procedure history is not about six weeks of a practice''s days with one cancelled';
  end if;
end;
$$;
commit;

-- What the history wrote, read as the database holds it --------------------------------------------------------------

do $$
declare
  c uuid := (select clinic from check_args);
  v_tz text := (select time_zone from public.clinics where id = c);
  v_start timestamptz := (date_trunc('week', (now() at time zone v_tz)::date - 42)::date + time '07:00') at time zone v_tz;
  v_wrong text;
begin
  -- Every product's stock is what its ledger adds up to, and no batch holds less than 0.
  select string_agg(p.name, ', ') into v_wrong
  from public.products p join public.product_stock s on s.product_id = p.id
  where p.clinic_id = c
    and s.quantity <> (select coalesce(sum(t.delta), 0) from public.transactions t where t.product_id = p.id);
  if v_wrong is not null or exists (select 1 from public.batches b where b.clinic_id = c and b.qty < 0) then
    raise exception 'The ledger does not end at the stock (or a batch is below 0) for: %', v_wrong;
  end if;

  -- Nothing is dated after now, and nothing the story wrote before its first morning.
  if exists (select 1 from public.transactions where clinic_id = c and greatest(at, created_at) > now())
     or exists (select 1 from public.stock_actions where clinic_id = c and created_at > now())
     or exists (select 1 from public.batches where clinic_id = c and created_at > now())
     or exists (select 1 from public.open_items where clinic_id = c and greatest(opened_at, finished_at) > now())
     or exists (select 1 from public.procedure_events where clinic_id = c and greatest(started_at, cancelled_at) > now())
     or exists (select 1 from public.procedure_event_items where clinic_id = c and created_at > now())
     or exists (select 1 from public.procedure_templates where clinic_id = c and created_at > now())
     or exists (select 1 from public.to_buy_items where clinic_id = c
                and greatest(created_at, ordered_at, received_at) > now())
     or exists (select 1 from public.alerts where clinic_id = c and greatest(opened_at, resolved_at) > now())
     -- A push's not_before is when it may go out, not when anything happened: one queued at night waits for 7 am.
     or exists (select 1 from public.push_outbox where clinic_id = c and created_at > now())
  then
    raise exception 'A row is dated in the future';
  end if;
  if exists (select 1 from public.transactions t join public.products p on p.id = t.product_id
             where t.clinic_id = c and p.archived_at is null and t.at < v_start)
     or exists (select 1 from public.procedure_events where clinic_id = c and started_at < v_start)
     or exists (select 1 from public.alerts where clinic_id = c and opened_at < v_start)
     or exists (select 1 from public.to_buy_items where clinic_id = c and created_at < v_start)
     or exists (select 1 from public.procedure_templates where clinic_id = c and created_at < v_start)
  then
    raise exception 'A row the story wrote is dated before its first morning';
  end if;
  if exists (select 1 from public.alerts where clinic_id = c and resolved_at < opened_at)
     or exists (select 1 from public.open_items where clinic_id = c and finished_at < opened_at)
     or exists (select 1 from public.to_buy_items where clinic_id = c
                and (ordered_at < created_at or received_at < ordered_at))
  then
    raise exception 'Something closes before it opens';
  end if;

  -- The ledger's append-only triggers are back on.
  if exists (select 1 from pg_catalog.pg_trigger t
             where t.tgrelid = 'public.transactions'::regclass
               and t.tgname in ('transactions_append_only', 'transactions_append_only_truncate')
               and t.tgenabled <> 'O')
     or (select count(*) from pg_catalog.pg_trigger t
         where t.tgrelid = 'public.transactions'::regclass
           and t.tgname in ('transactions_append_only', 'transactions_append_only_truncate')) <> 2
  then
    raise exception 'The ledger''s append-only triggers are not both on';
  end if;

  -- Nothing waits to be pushed or emailed.
  if exists (select 1 from public.push_outbox where clinic_id = c and sent_at is null and skipped is null)
     or exists (select 1 from public.digest_sends where clinic_id = c)
  then
    raise exception 'A push or a digest of the clinic waits to be sent';
  end if;

  -- Pen and Pain killer archived as Delete product leaves a product, their history kept.
  if (select count(*) from public.products
      where clinic_id = c and name in ('Pen', 'Pain killer') and archived_at is not null) <> 2
     or exists (select 1 from public.alerts a join public.products p on p.id = a.product_id
                where p.clinic_id = c and p.name in ('Pen', 'Pain killer') and a.resolved_at is null)
     or exists (select 1 from public.to_buy_items t join public.products p on p.id = t.product_id
                where p.clinic_id = c and p.name in ('Pen', 'Pain killer') and t.status in ('to_buy', 'ordered'))
     or (select count(*) from public.transactions t join public.products p on p.id = t.product_id
         where p.clinic_id = c and p.name in ('Pen', 'Pain killer')) <> 3
  then
    raise exception 'Pen and Pain killer are not archived with their history';
  end if;

  -- A supplier on every catalog product; every multi-use product the story uses has one bottle open.
  if exists (select 1 from public.products where clinic_id = c and archived_at is null and supplier is null)
     or exists (select 1 from public.products p join public.product_stock s on s.product_id = p.id
                where p.clinic_id = c and p.archived_at is null and p.tracking = 'multi_use'
                  and p.name <> 'Pit and fissure sealant' and s.open_count <> 1)
  then
    raise exception 'A product has no supplier, or a multi-use product in use has not one bottle open';
  end if;
end;
$$;

\echo
\echo 'The demo history on a new clinic: what Inventory, To buy and Expiring soon read'
select s.status as "Status", count(*) as "Products"
from public.inventory_list((select clinic from check_args)) s
group by s.status
order by min(case s.status when 'out_of_stock' then 1 when 'low' then 2 when 'expiring' then 3
  when 'missing_expiry' then 4 else 5 end);
select t.status as "To buy", t.name as "Product", trim_scale(t.qty) as "Quantity"
from public.to_buy_list((select clinic from check_args)) t
where t.status <> 'received'
order by t.status desc, t.name;
select b ->> 'name' as "Expiring soon", b ->> 'lot' as "Lot", b ->> 'expiry_month' as "Expires",
  trim_scale((b ->> 'qty')::numeric) as "Quantity", b ->> 'value' as "Value"
from jsonb_array_elements(public.expiring_batches((select clinic from check_args)) -> 'batches') b
order by b ->> 'expiry_month';
