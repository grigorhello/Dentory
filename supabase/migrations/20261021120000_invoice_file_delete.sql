-- MS-146 · Let admins delete invoice files (PRD §9 Privacy: invoice images belong to the clinic and can be deleted by
-- an admin). A received invoice, opened read-only from Activity's History, has Delete invoice file in its "…" menu:
-- invoice_file_delete lets go of the invoice's photo or PDF (storage_path, file_kind and file_count become null, and who
-- did it and when are kept), then the app deletes the pages through the Storage API. The invoices bucket refuses to
-- delete a received invoice's pages while the invoice holds their folder (MS-131's invoices_admin_delete, unchanged), so
-- they go only once an admin of a clinic that may write has let go of them here. The lines, the stock received, the
-- ledger and History stay. An invoice now says whether a page of it is still in the bucket (has_file), so a deletion
-- whose pages were not all deleted (the connection lost in between) is offered again, and finished.

-- Who deleted an invoice's file, and when -------------------------------------------------------------------------------

alter table public.invoices
  add column file_deleted_at timestamptz,
  add column file_deleted_by uuid references auth.users (id),
  add constraint invoices_file_deletion check ((file_deleted_at is null) = (file_deleted_by is null));

-- An invoice from a photo or a file keeps where its pages are, until an admin deletes them.
alter table public.invoices drop constraint invoices_file;
alter table public.invoices add constraint invoices_file
  check (source = 'manual' or storage_path is not null or file_deleted_at is not null);

-- Whether an invoice still has its file -----------------------------------------------------------------------------------

-- Every name an invoice's pages can have in the invoices bucket, which takes no other (MS-129: page-1.jpg to
-- page-20.jpg, or page-1.pdf), the ids in lower case as the app writes them: looked up through the bucket's index.
create function engine.invoice_page_names(p_clinic_id uuid, p_invoice_id uuid)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array_agg(p_clinic_id || '/' || p_invoice_id || '/page-' || n || '.jpg' order by n)
    || (p_clinic_id || '/' || p_invoice_id || '/page-1.pdf')
  from generate_series(1, 20) n;
$$;
revoke execute on function engine.invoice_page_names(uuid, uuid) from public, anon, authenticated;

-- What the screen reads of one invoice: MS-131's answer, with whether a page of it is still in the bucket and, once its
-- file was deleted, when and by whom. A received invoice offers Delete invoice file while it has a page left.
create or replace function engine.invoice_json(p_invoice_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', i.id, 'status', i.status, 'source', i.source, 'supplier', i.supplier, 'number', i.number,
    'invoice_date', i.invoice_date, 'total', i.total, 'currency', i.currency, 'created_at', i.created_at,
    'reading_started', i.read_started_at is not null, 'read_at', i.read_at, 'failure_reason', i.failure_reason,
    'line_count', (select count(*) from public.invoice_lines l where l.invoice_id = i.id),
    'confirmed_at', i.confirmed_at,
    'confirmed_by_name', (
      select m.full_name from public.memberships m where m.clinic_id = i.clinic_id and m.user_id = i.confirmed_by
    ),
    'has_file', exists (
      select 1 from storage.objects o
      where o.bucket_id = 'invoices' and o.name = any (engine.invoice_page_names(i.clinic_id, i.id))
    ),
    'file_deleted_at', i.file_deleted_at,
    'file_deleted_by_name', (
      select m.full_name from public.memberships m where m.clinic_id = i.clinic_id and m.user_id = i.file_deleted_by
    )
  )
  from public.invoices i
  where i.id = p_invoice_id;
$$;

-- Delete invoice file -----------------------------------------------------------------------------------------------------

-- An admin of the invoice's clinic, a clinic that may write (MS-142) and a received invoice: the invoice lets go of its
-- photo or PDF, keeping who did it and when, and the app then deletes the pages, which the invoices bucket allows once no
-- received invoice holds their folder. Asked again (pages left by a deletion cut short), it changes nothing and answers
-- the invoice, so the app deletes what is left. An invoice waiting for review is discarded instead (MS-130), which
-- deletes its pages too. Answers the invoice as the screen reads it.
create function public.invoice_file_delete(p_invoice_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invoice public.invoices;
begin
  select * into v_invoice from public.invoices i where i.id = p_invoice_id for update;
  if v_invoice.id is null or not coalesce(public.is_admin(v_invoice.clinic_id), false) then
    perform engine.fail('42501', 'Only an admin can delete invoice files');
  end if;
  if not public.clinic_can_write(v_invoice.clinic_id) then
    perform engine.fail('42501', 'The clinic is read-only until a payment method is added');
  end if;
  if v_invoice.status <> 'confirmed' then
    perform engine.fail('22023', 'Only a received invoice''s file can be deleted');
  end if;
  update public.invoices
  set storage_path = null, file_kind = null, file_count = null, file_deleted_at = now(), file_deleted_by = auth.uid()
  where id = p_invoice_id and storage_path is not null;
  return engine.invoice_json(p_invoice_id);
end;
$$;
revoke execute on function public.invoice_file_delete(uuid) from public, anon;
grant execute on function public.invoice_file_delete(uuid) to authenticated, service_role;
