-- MS-104 · The V1.1 schema (PRD §4 data model, §5 status rules, §9 audit; decisions in MS-100).
-- Every business table carries clinic_id. Products are archived, never deleted. The transactions
-- ledger is append-only. Row level security is switched on everywhere with no policies yet, so the
-- API sees nothing until MS-105 adds the clinic and role policies.

-- Closed sets --------------------------------------------------------------------------------------

create type public.membership_role as enum ('admin', 'staff');
create type public.membership_status as enum ('active', 'invited', 'revoked');
create type public.subscription_status as enum ('trialing', 'active', 'past_due', 'canceled', 'read_only');
create type public.tracking_mode as enum ('countable', 'multi_use');
create type public.to_buy_source as enum ('auto', 'manual');
create type public.to_buy_status as enum ('to_buy', 'ordered', 'received');
create type public.invoice_source as enum ('camera', 'file', 'manual');
create type public.invoice_status as enum ('reading', 'ready', 'failed', 'confirmed', 'discarded');
create type public.invoice_line_state as enum ('matched', 'possible_match', 'new_product', 'needs_review', 'created', 'skipped');
create type public.transaction_type as enum ('receiving', 'procedure', 'count', 'adjustment', 'disposal', 'cancellation');
create type public.transaction_ref_type as enum ('invoice', 'procedure_event', 'count_session', 'manual', 'undo');
create type public.alert_kind as enum ('out_of_stock', 'low', 'expiring', 'missing_expiry', 'invoice_ready');
create type public.export_status as enum ('queued', 'running', 'done', 'failed');

-- Clinic and people --------------------------------------------------------------------------------

create table public.clinics (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null check (length(btrim(name)) between 1 and 120),
  logo_path text,
  city text,
  country char(2) not null check (country ~ '^[A-Z]{2}$'),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  -- MS-100 D14: time zone shown in Clinic settings, prefilled from the device.
  time_zone text not null default 'UTC',
  -- MS-100 D8: the chosen thresholds; a batch is Expiring within the largest one.
  expiry_thresholds int[] not null default '{30,60,90}'
    check (expiry_thresholds in ('{30,60,90}'::int[], '{60,90}'::int[], '{90}'::int[])),
  email_digest boolean not null default false,
  trial_ends_at timestamptz not null default now() + interval '3 months',
  subscription_status public.subscription_status not null default 'trialing',
  promo_lifetime_50 boolean not null default false,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  billing_emails text[] not null default '{}'
);

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  full_name text not null default ''
);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  -- Null until the invitation is accepted. An account cannot be removed while a membership row
  -- still holds its user_id: clear user_id or delete the membership first.
  user_id uuid references auth.users (id) on delete restrict,
  email text not null check (position('@' in email) > 1),
  full_name text not null default '',
  role public.membership_role not null default 'staff',
  status public.membership_status not null default 'invited',
  invited_by uuid references auth.users (id) on delete set null,
  invited_at timestamptz not null default now(),
  invite_token_hash text,
  invite_expires_at timestamptz,
  constraint memberships_active_has_user check (status <> 'active' or user_id is not null)
);
create unique index memberships_clinic_email_key on public.memberships (clinic_id, lower(email));
create unique index memberships_clinic_user_key on public.memberships (clinic_id, user_id) where user_id is not null;
create index memberships_user_idx on public.memberships (user_id);

-- Catalog ------------------------------------------------------------------------------------------

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 60),
  position integer not null default 0,
  unique (id, clinic_id)
);
create unique index categories_clinic_name_key on public.categories (clinic_id, lower(name));

create table public.products (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 120),
  category_id uuid,
  -- The unit the product is counted in (cartridges); optionally received as packs of pack_size units (1 box = 50).
  unit text not null check (length(btrim(unit)) between 1 and 40),
  pack_unit text,
  pack_size integer,
  minimum numeric(12, 2) not null default 0 check (minimum >= 0),
  target numeric(12, 2) not null default 0 check (target >= 0),
  supplier text,
  location text,
  tracking public.tracking_mode not null default 'countable',
  -- Per counted unit, from the last receiving.
  last_unit_cost numeric(12, 4) check (last_unit_cost >= 0),
  archived_at timestamptz,
  unique (id, clinic_id),
  foreign key (category_id, clinic_id) references public.categories (id, clinic_id) on delete set null (category_id),
  constraint products_pack check (
    (pack_unit is null and pack_size is null)
    or (pack_unit is not null and pack_size is not null and pack_size > 1)
  )
);
create index products_clinic_active_idx on public.products (clinic_id) where archived_at is null;
create index products_category_idx on public.products (category_id);

-- Products are archived, never deleted (PRD §4, §9): no role may delete, and the trigger stops the owner too.
revoke delete, truncate on public.products from public, anon, authenticated, service_role;

create function public.products_archive_only()
returns trigger
language plpgsql
as $$
begin
  raise exception 'products are archived, never deleted: set archived_at instead'
    using errcode = 'restrict_violation';
end;
$$;

create trigger products_archive_only
  before delete on public.products
  for each row execute function public.products_archive_only();

create trigger products_archive_only_truncate
  before truncate on public.products
  for each statement execute function public.products_archive_only();

-- Stock --------------------------------------------------------------------------------------------

create table public.batches (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  product_id uuid not null,
  -- First day of the month; null is the undated quantity shown as Missing expiry.
  expiry_month date check (expiry_month = date_trunc('month', expiry_month)::date),
  lot text,
  qty numeric(12, 2) not null default 0,
  unique (id, clinic_id),
  foreign key (product_id, clinic_id) references public.products (id, clinic_id) on delete cascade,
  -- MS-100 D9: stock may go negative, and the negative sits on the undated batch only.
  constraint batches_negative_only_undated check (qty >= 0 or expiry_month is null)
);
create index batches_product_expiry_idx on public.batches (product_id, expiry_month);

create table public.procedure_templates (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 120),
  archived_at timestamptz,
  unique (id, clinic_id)
);
create unique index procedure_templates_clinic_name_key
  on public.procedure_templates (clinic_id, lower(name)) where archived_at is null;

create table public.procedure_template_items (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  template_id uuid not null,
  product_id uuid not null,
  -- Multi-use products default to 0: the open one is used.
  default_qty numeric(12, 2) not null default 1 check (default_qty >= 0),
  position integer not null default 0,
  foreign key (template_id, clinic_id) references public.procedure_templates (id, clinic_id) on delete cascade,
  foreign key (product_id, clinic_id) references public.products (id, clinic_id) on delete cascade,
  unique (template_id, product_id)
);

create table public.procedure_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  template_id uuid,
  -- Snapshot of the template name at the time.
  name text not null,
  started_by uuid not null references auth.users (id),
  started_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancelled_by uuid references auth.users (id),
  cancel_note text,
  unique (id, clinic_id),
  foreign key (template_id, clinic_id) references public.procedure_templates (id, clinic_id) on delete set null (template_id),
  -- Cancelling requires a note (PRD §4).
  constraint procedure_events_cancellation check (
    (cancelled_at is null and cancelled_by is null and cancel_note is null)
    or (cancelled_at is not null and cancelled_by is not null and coalesce(length(btrim(cancel_note)), 0) > 0)
  )
);
create index procedure_events_clinic_started_idx on public.procedure_events (clinic_id, started_at desc);

create table public.open_items (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  product_id uuid not null,
  opened_by uuid not null references auth.users (id),
  opened_at timestamptz not null default now(),
  opened_in_event_id uuid,
  finished_at timestamptz,
  finished_by uuid references auth.users (id),
  unique (id, clinic_id),
  foreign key (product_id, clinic_id) references public.products (id, clinic_id) on delete cascade,
  foreign key (opened_in_event_id, clinic_id) references public.procedure_events (id, clinic_id) on delete set null (opened_in_event_id),
  constraint open_items_finished check ((finished_at is null) = (finished_by is null))
);
create index open_items_product_open_idx on public.open_items (product_id) where finished_at is null;

create table public.procedure_event_items (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  event_id uuid not null,
  product_id uuid not null,
  qty numeric(12, 2) not null check (qty >= 0),
  foreign key (event_id, clinic_id) references public.procedure_events (id, clinic_id) on delete cascade,
  foreign key (product_id, clinic_id) references public.products (id, clinic_id) on delete cascade,
  unique (event_id, product_id)
);

create table public.procedure_event_openings (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  event_id uuid not null,
  product_id uuid not null,
  open_item_id uuid not null,
  foreign key (event_id, clinic_id) references public.procedure_events (id, clinic_id) on delete cascade,
  foreign key (product_id, clinic_id) references public.products (id, clinic_id) on delete cascade,
  foreign key (open_item_id, clinic_id) references public.open_items (id, clinic_id) on delete cascade,
  unique (event_id, open_item_id)
);

-- Receiving ----------------------------------------------------------------------------------------

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  storage_path text,
  source public.invoice_source not null,
  status public.invoice_status not null default 'reading',
  supplier text,
  number text,
  invoice_date date,
  total numeric(12, 2),
  currency char(3) check (currency ~ '^[A-Z]{3}$'),
  raw_extraction jsonb,
  created_by uuid not null references auth.users (id),
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users (id),
  unique (id, clinic_id),
  constraint invoices_confirmation check ((confirmed_at is null) = (confirmed_by is null)),
  constraint invoices_file check (source = 'manual' or storage_path is not null)
);
create index invoices_clinic_created_idx on public.invoices (clinic_id, created_at desc);

create table public.invoice_lines (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  invoice_id uuid not null,
  n integer not null check (n >= 1),
  raw text not null,
  qty numeric(12, 2),
  unit text,
  unit_price numeric(12, 4),
  line_total numeric(12, 2),
  state public.invoice_line_state not null default 'needs_review',
  suggested_product_id uuid,
  product_id uuid,
  lot text,
  expiry_month date check (expiry_month = date_trunc('month', expiry_month)::date),
  foreign key (invoice_id, clinic_id) references public.invoices (id, clinic_id) on delete cascade,
  foreign key (suggested_product_id, clinic_id) references public.products (id, clinic_id) on delete set null (suggested_product_id),
  foreign key (product_id, clinic_id) references public.products (id, clinic_id) on delete set null (product_id),
  unique (invoice_id, n)
);

create table public.supplier_aliases (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  supplier text not null default '',
  raw_text_normalized text not null,
  product_id uuid not null,
  foreign key (product_id, clinic_id) references public.products (id, clinic_id) on delete cascade,
  unique (clinic_id, supplier, raw_text_normalized)
);

create table public.to_buy_items (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  product_id uuid not null,
  qty numeric(12, 2) not null check (qty >= 0),
  qty_edited boolean not null default false,
  source public.to_buy_source not null default 'auto',
  status public.to_buy_status not null default 'to_buy',
  added_by uuid references auth.users (id) on delete set null,
  ordered_at timestamptz,
  ordered_by uuid references auth.users (id),
  received_at timestamptz,
  invoice_id uuid,
  foreign key (product_id, clinic_id) references public.products (id, clinic_id) on delete cascade,
  foreign key (invoice_id, clinic_id) references public.invoices (id, clinic_id) on delete set null (invoice_id),
  constraint to_buy_items_ordered check (status = 'to_buy' or ordered_at is not null),
  constraint to_buy_items_received check (status <> 'received' or received_at is not null)
);
-- One open To buy line per product; it is recalculated until marked Ordered (PRD §5).
create unique index to_buy_items_open_product_key on public.to_buy_items (product_id) where status = 'to_buy';
create index to_buy_items_clinic_status_idx on public.to_buy_items (clinic_id, status);

-- Ledger -------------------------------------------------------------------------------------------

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete restrict,
  product_id uuid not null,
  batch_id uuid,
  open_item_id uuid,
  type public.transaction_type not null,
  delta numeric(12, 2) not null,
  -- Product totals around this row.
  qty_before numeric(12, 2) not null,
  qty_after numeric(12, 2) not null,
  by_user uuid not null references auth.users (id),
  at timestamptz not null default now(),
  ref_type public.transaction_ref_type not null,
  ref_id uuid,
  ref_label text,
  reason text,
  note text,
  reverses_id uuid,
  -- Groups the rows one user action wrote; Undo reverses a whole action (MS-100 D10).
  action_id uuid not null,
  unique (id, clinic_id),
  foreign key (reverses_id, clinic_id) references public.transactions (id, clinic_id),
  foreign key (product_id, clinic_id) references public.products (id, clinic_id) on delete restrict,
  foreign key (batch_id, clinic_id) references public.batches (id, clinic_id) on delete restrict,
  foreign key (open_item_id, clinic_id) references public.open_items (id, clinic_id) on delete restrict,
  constraint transactions_totals check (qty_after = qty_before + delta)
);
create index transactions_product_at_idx on public.transactions (product_id, at desc);
create index transactions_clinic_at_idx on public.transactions (clinic_id, at desc);
create index transactions_action_idx on public.transactions (action_id);

-- Append-only: no role may change or remove a row, and the triggers catch the owner too.
revoke update, delete, truncate on public.transactions from public, anon, authenticated, service_role;

create function public.transactions_append_only()
returns trigger
language plpgsql
as $$
begin
  raise exception 'transactions is append-only: write a reversal instead of changing history'
    using errcode = 'restrict_violation';
end;
$$;

create trigger transactions_append_only
  before update or delete on public.transactions
  for each row execute function public.transactions_append_only();

-- TRUNCATE fires no row triggers, so it gets its own statement trigger.
create trigger transactions_append_only_truncate
  before truncate on public.transactions
  for each statement execute function public.transactions_append_only();

-- Alerts and devices -------------------------------------------------------------------------------

create table public.alerts (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  kind public.alert_kind not null,
  product_id uuid,
  batch_id uuid,
  invoice_id uuid,
  threshold_days integer check (threshold_days in (30, 60, 90)),
  opened_at timestamptz not null default now(),
  resolved_at timestamptz,
  foreign key (product_id, clinic_id) references public.products (id, clinic_id) on delete cascade,
  foreign key (batch_id, clinic_id) references public.batches (id, clinic_id) on delete cascade,
  foreign key (invoice_id, clinic_id) references public.invoices (id, clinic_id) on delete cascade,
  -- Each kind names exactly its subject and nothing else.
  constraint alerts_subject check (
    case kind
      when 'invoice_ready' then invoice_id is not null and product_id is null and batch_id is null and threshold_days is null
      when 'expiring' then product_id is not null and batch_id is not null and threshold_days is not null and invoice_id is null
      else product_id is not null and batch_id is null and threshold_days is null and invoice_id is null
    end
  )
);
-- One open alert per subject; nulls count as equal so (low, product) cannot open twice.
create unique index alerts_open_key
  on public.alerts (clinic_id, kind, product_id, batch_id, invoice_id, threshold_days)
  nulls not distinct
  where resolved_at is null;
create index alerts_clinic_open_idx on public.alerts (clinic_id, opened_at desc) where resolved_at is null;

create table public.alert_reads (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  last_seen_at timestamptz not null default now(),
  unique (clinic_id, user_id)
);

create table public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null unique,
  platform text not null default 'ios' check (platform in ('ios')),
  updated_at timestamptz not null default now()
);

create table public.export_jobs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  requested_by uuid not null references auth.users (id),
  status public.export_status not null default 'queued',
  file_path text,
  finished_at timestamptz
);

-- Quantity helpers ---------------------------------------------------------------------------------

-- Stock per product (PRD §4): unopened is the sum of its batches; multi-use products add their open
-- items; missing_expiry_qty is the undated quantity (never below 0, since a negative undated batch is
-- a shortfall, not undated stock); soonest_expiry ignores empty batches.
create view public.product_stock
with (security_invoker = true)
as
select
  p.id as product_id,
  p.clinic_id,
  p.tracking,
  coalesce(b.unopened, 0)::numeric(12, 2) as unopened,
  coalesce(o.open_count, 0)::integer as open_count,
  (coalesce(b.unopened, 0) + case when p.tracking = 'multi_use' then coalesce(o.open_count, 0) else 0 end)::numeric(12, 2) as quantity,
  greatest(coalesce(b.missing_expiry_qty, 0), 0)::numeric(12, 2) as missing_expiry_qty,
  b.soonest_expiry
from public.products p
left join (
  select
    product_id,
    sum(qty) as unopened,
    sum(qty) filter (where expiry_month is null) as missing_expiry_qty,
    min(expiry_month) filter (where qty > 0) as soonest_expiry
  from public.batches
  group by product_id
) b on b.product_id = p.id
left join (
  select product_id, count(*) as open_count
  from public.open_items
  where finished_at is null
  group by product_id
) o on o.product_id = p.id;

-- Isolation ----------------------------------------------------------------------------------------

-- No policies yet: the API cannot read or write any row until MS-105 adds them.
alter table public.clinics enable row level security;
alter table public.profiles enable row level security;
alter table public.memberships enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.batches enable row level security;
alter table public.procedure_templates enable row level security;
alter table public.procedure_template_items enable row level security;
alter table public.procedure_events enable row level security;
alter table public.open_items enable row level security;
alter table public.procedure_event_items enable row level security;
alter table public.procedure_event_openings enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_lines enable row level security;
alter table public.supplier_aliases enable row level security;
alter table public.to_buy_items enable row level security;
alter table public.transactions enable row level security;
alter table public.alerts enable row level security;
alter table public.alert_reads enable row level security;
alter table public.push_tokens enable row level security;
alter table public.export_jobs enable row level security;
