-- MS-146 fix (Refs #117) · Delete invoice file stays open in read-only mode, as decided on #117 on 2026-10-26: a clinic
-- whose trial ended without a card, or whose subscription stopped, can still remove its invoice images, as the privacy
-- page promises ("an Admin can delete them at any time") and as MS-129's bucket rule already allows (admins delete
-- the clinic's files, read-only or not). invoice_file_delete keeps its other checks, an admin of the invoice's clinic
-- and a received invoice, and no longer asks for a clinic that may write (MS-142). The invoices bucket is unchanged:
-- MS-131's invoices_admin_delete still refuses a received invoice's pages while the invoice holds their folder, and lets
-- only the clinic's admins delete them once this function has let go of them; it never asked for a clinic that may
-- write. Every other write of a read-only clinic stays refused, Discard invoice included. MS-146's function, redefined
-- from 20261021120000_invoice_file_delete.sql (20261021130000_security_review.sql left it as it was), unchanged but
-- for the read-only check; its grants stay (members execute it, the anon key does not).

-- Delete invoice file -----------------------------------------------------------------------------------------------------

-- An admin of the invoice's clinic, read-only or not, and a received invoice: the invoice lets go of its photo or PDF,
-- keeping who did it and when, and the app then deletes the pages, which the invoices bucket allows once no received
-- invoice holds their folder. Security definer, so MS-142's trigger on invoices lets a read-only clinic's change through.
-- Asked again (pages left by a deletion cut short), it changes nothing and answers the invoice, so the app deletes what
-- is left. An invoice waiting for review is discarded instead (MS-130), which deletes its pages too. Answers the invoice
-- as the screen reads it.
create or replace function public.invoice_file_delete(p_invoice_id uuid)
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
  if v_invoice.status <> 'confirmed' then
    perform engine.fail('22023', 'Only a received invoice''s file can be deleted');
  end if;
  update public.invoices
  set storage_path = null, file_kind = null, file_count = null, file_deleted_at = now(), file_deleted_by = auth.uid()
  where id = p_invoice_id and storage_path is not null;
  return engine.invoice_json(p_invoice_id);
end;
$$;
