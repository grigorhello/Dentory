-- Every table, type, index and trigger of MS-104 exists, every business table carries clinic_id,
-- and row level security is on everywhere.
begin;
select plan(78);

select has_table('public', t, 'table ' || t || ' exists')
from unnest(array[
  'clinics', 'profiles', 'memberships', 'categories', 'products', 'batches',
  'procedure_templates', 'procedure_template_items', 'procedure_events', 'open_items',
  'procedure_event_items', 'procedure_event_openings', 'invoices', 'invoice_lines',
  'supplier_aliases', 'to_buy_items', 'transactions', 'alerts', 'alert_reads', 'push_tokens', 'export_jobs'
]) as t;

select has_column('public', t, 'clinic_id', t || ' is isolated per clinic')
from unnest(array[
  'memberships', 'categories', 'products', 'batches',
  'procedure_templates', 'procedure_template_items', 'procedure_events', 'open_items',
  'procedure_event_items', 'procedure_event_openings', 'invoices', 'invoice_lines',
  'supplier_aliases', 'to_buy_items', 'transactions', 'alerts', 'alert_reads', 'export_jobs'
]) as t;

select ok(c.relrowsecurity, t || ' has row level security on')
from unnest(array[
  'clinics', 'profiles', 'memberships', 'categories', 'products', 'batches',
  'procedure_templates', 'procedure_template_items', 'procedure_events', 'open_items',
  'procedure_event_items', 'procedure_event_openings', 'invoices', 'invoice_lines',
  'supplier_aliases', 'to_buy_items', 'transactions', 'alerts', 'alert_reads', 'push_tokens', 'export_jobs'
]) as t
join pg_class c on c.oid = ('public.' || t)::regclass;

select has_type('public', e, 'enum ' || e || ' exists')
from unnest(array[
  'membership_role', 'membership_status', 'subscription_status', 'tracking_mode', 'to_buy_source',
  'to_buy_status', 'invoice_source', 'invoice_status', 'invoice_line_state', 'transaction_type',
  'transaction_ref_type', 'alert_kind', 'export_status'
]) as e;

select has_view('public', 'product_stock', 'product_stock view exists');
select has_trigger('public', 'transactions', 'transactions_append_only', 'the ledger has its append-only trigger');
select has_index('public', 'batches', 'batches_product_expiry_idx', 'batches are indexed by product and expiry');
select has_index('public', 'memberships', 'memberships_clinic_email_key', 'one membership per email per clinic');
select has_index('public', 'alerts', 'alerts_open_key', 'one open alert per subject');

select * from finish();
rollback;
