-- MS-117 · Create, edit and delete products (PRD §6.4, Appendix C newProduct and deleteProduct).
-- Admins write products and categories through the MS-105 policies; this migration adds the rules
-- around those writes: the alerts follow a product's levels, a product with stock keeps its tracking
-- mode, the target never drops under the minimum, a category is found or created in one call, and
-- "Delete product" archives (products are never deleted: PRD §4) while clearing the product out of the
-- templates and the open To buy lines. `product_detail` also answers the category id and the supplier
-- the Edit sheet starts from.

-- Levels and tracking -------------------------------------------------------------------------------

-- Target at least the minimum (the sheet says "Reorder up to"), and no change of how a product is
-- tracked while it holds any stock: the app shows "Set stock to 0 before changing how it is tracked."
-- Stock may go negative (MS-100 D9) and a multi-use product's quantity adds its open bottles, so a
-- quantity of 0 can still hide -1 unopened and 1 open: the batches and the open bottles are checked.
create function public.products_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_unopened numeric;
  v_open integer;
begin
  if new.target < new.minimum then
    raise exception 'Target must be at least the minimum.' using errcode = '22023';
  end if;
  if tg_op = 'UPDATE' and new.tracking is distinct from old.tracking then
    select coalesce(s.unopened, 0), coalesce(s.open_count, 0) into v_unopened, v_open
    from public.product_stock s where s.product_id = new.id;
    if coalesce(v_unopened, 0) <> 0 or coalesce(v_open, 0) > 0 then
      raise exception 'Set stock to 0 before changing how it is tracked.' using errcode = '22023';
    end if;
  end if;
  return new;
end;
$$;

create trigger products_validate
  before insert or update of minimum, target, tracking on public.products
  for each row execute function public.products_validate();

-- Changing the minimum, the target or the tracking re-runs refresh_product (the Low and Out of stock
-- alerts and the auto To buy line follow the levels); archiving resolves every open alert of the product.
-- A value must change: the Edit sheet sends every column, and a new name is not a new level. A new
-- product is not refreshed on insert: the engine refreshes it at its first stock change (MS-100 G6), or
-- refresh_all_products does at 07:00 (pg_cron, MS-107).
create function public.products_refresh_alerts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.archived_at is null then
    perform public.refresh_product(new.id);
  else
    update public.alerts set resolved_at = now() where product_id = new.id and resolved_at is null;
  end if;
  return null;
end;
$$;

create trigger products_refresh_alerts
  after update of minimum, target, tracking, archived_at on public.products
  for each row
  when (
    old.minimum is distinct from new.minimum or old.target is distinct from new.target
    or old.tracking is distinct from new.tracking or old.archived_at is distinct from new.archived_at
  )
  execute function public.products_refresh_alerts();

-- Categories ----------------------------------------------------------------------------------------

-- "New category…" on the sheet (MS-100 D13): the clinic's category of that name, case-insensitive, or
-- a new one at the end of the list. Security invoker: the categories policies decide (admins only).
create function public.category_find_or_create(p_clinic_id uuid, p_name text)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text := btrim(p_name);
  v_id uuid;
  v_stored text;
begin
  if length(v_name) < 1 or length(v_name) > 60 then
    raise exception 'Enter a category name of 60 characters or fewer.' using errcode = '22023';
  end if;
  select c.id, c.name into v_id, v_stored
  from public.categories c
  where c.clinic_id = p_clinic_id and lower(c.name) = lower(v_name);
  if v_id is null then
    insert into public.categories (clinic_id, name, position)
    values (
      p_clinic_id, v_name,
      (select coalesce(max(c.position), 0) + 1 from public.categories c where c.clinic_id = p_clinic_id)
    )
    returning id, name into v_id, v_stored;
  end if;
  return jsonb_build_object('id', v_id, 'name', v_stored);
end;
$$;

revoke execute on function public.category_find_or_create(uuid, text) from public, anon;
grant execute on function public.category_find_or_create(uuid, text) to authenticated, service_role;

-- Delete product ------------------------------------------------------------------------------------

-- Archives the product (history kept), takes it off every procedure template and the open To buy lines
-- (to_buy and ordered; received lines are history). Admin only, and only while the clinic can write.
create function public.product_archive(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product public.products;
begin
  select * into v_product from public.products p where p.id = p_product_id;
  if v_product.id is null then
    raise exception 'unknown product' using errcode = '22023';
  end if;
  -- is_admin is null for someone outside the clinic: that is a refusal too.
  if not coalesce(public.is_admin(v_product.clinic_id), false) then
    raise exception 'only an admin can do this' using errcode = '42501';
  end if;
  if not public.clinic_can_write(v_product.clinic_id) then
    raise exception 'the clinic is read-only until a payment method is added' using errcode = '42501';
  end if;
  if v_product.archived_at is not null then
    raise exception 'the product is archived' using errcode = '22023';
  end if;
  update public.products set archived_at = now() where id = p_product_id;
  delete from public.procedure_template_items where product_id = p_product_id;
  delete from public.to_buy_items where product_id = p_product_id and status in ('to_buy', 'ordered');
end;
$$;

revoke execute on function public.product_archive(uuid) from public, anon;
grant execute on function public.product_archive(uuid) to authenticated, service_role;

-- Product detail: the Edit sheet starts from the category id and the supplier too --------------------

create or replace function public.product_detail(p_product_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'product', (
      select jsonb_build_object(
        'id', p.id, 'name', p.name, 'category_id', p.category_id, 'category_name', c.name, 'unit', p.unit,
        'pack_unit', p.pack_unit, 'pack_size', p.pack_size, 'minimum', p.minimum, 'target', p.target,
        'tracking', p.tracking, 'supplier', p.supplier, 'location', p.location, 'status', s.status,
        'quantity', s.quantity, 'unopened', s.unopened, 'open_count', s.open_count,
        'missing_expiry_qty', s.missing_expiry_qty
      )
      from public.products p
      join public.product_status s on s.product_id = p.id
      left join public.categories c on c.id = p.category_id
      where p.id = p_product_id and p.archived_at is null
    ),
    'used_in_30_days', (
      select greatest(coalesce(-sum(t.delta), 0), 0)
      from public.transactions t
      where t.product_id = p_product_id and t.type in ('procedure', 'cancellation')
        and t.at >= now() - interval '30 days'
    ),
    'last_counted_at', (
      select max(t.at) from public.transactions t where t.product_id = p_product_id and t.type = 'count'
    ),
    'to_buy_item_id', (
      select t.id from public.to_buy_items t
      where t.product_id = p_product_id and t.status in ('to_buy', 'ordered')
      order by t.created_at desc
      limit 1
    ),
    'batches', (
      select coalesce(jsonb_agg(
        jsonb_build_object('id', b.id, 'expiry_month', b.expiry_month, 'lot', b.lot, 'qty', b.qty)
        order by b.expiry_month asc nulls last, b.created_at asc
      ), '[]'::jsonb)
      from public.batches b
      where b.product_id = p_product_id and b.qty <> 0
    ),
    'open_items', (
      select coalesce(jsonb_agg(
        jsonb_build_object('id', o.id, 'opened_at', o.opened_at, 'opened_by_name', coalesce(m.full_name, ''))
        order by o.opened_at desc
      ), '[]'::jsonb)
      from public.open_items o
      left join public.memberships m on m.user_id = o.opened_by and m.clinic_id = o.clinic_id
      where o.product_id = p_product_id and o.finished_at is null
    ),
    'history', (
      select coalesce(jsonb_agg(to_jsonb(h) order by h.at desc), '[]'::jsonb)
      from (
        select t.id, t.type, t.delta, t.qty_before, t.qty_after, t.reason, t.ref_label, t.at,
               coalesce(m.full_name, '') as by_name
        from public.transactions t
        left join public.memberships m on m.user_id = t.by_user and m.clinic_id = t.clinic_id
        where t.product_id = p_product_id
        order by t.at desc
        limit 20
      ) h
    )
  );
$$;
