-- MS-150 · Before `make perf-concurrency`'s run (concurrency.sh): Load test dental's admin receives 500 more of every
-- multi-use product its procedure templates use, through stock_receive, so that no bottle the run opens is refused
-- for want of one.

do $$
begin
  if not exists (select 1 from public.clinics where id = '10ad0000-0000-4000-8000-000000000001') then
    raise exception 'No load-test clinic here. Run make db-reset seed-load first.';
  end if;
end;
$$;

begin;
select set_config('request.jwt.claims',
  json_build_object('sub', '10ad0000-0000-4000-8000-000100000001', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);
select public.stock_receive(
  '10ad0000-0000-4000-8000-000000000001',
  (
    select jsonb_agg(jsonb_build_object('product_id', p.id, 'qty', 500) order by p.id)
    from public.products p
    where p.clinic_id = '10ad0000-0000-4000-8000-000000000001' and p.tracking = 'multi_use' and p.archived_at is null
      and exists (select 1 from public.procedure_template_items i where i.product_id = p.id)
  ),
  gen_random_uuid(),
  'manual',
  null,
  'Stock for the concurrency run'
);
commit;
