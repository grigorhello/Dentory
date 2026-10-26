import Foundation

/// Review invoice (MS-129, MS-130): the upload, the invoice row, the reading and its progress, setting the invoice
/// aside, and its lines (`InvoiceLinesRepository`). Admin only; the server refuses anyone else, and a read-only
/// clinic's writes.
protocol InvoiceRepository: InvoiceLinesRepository {
    /// Flow step 1: the pages to `invoices/{clinic_id}/{invoice_id}/page-n.(jpg|pdf)`, replacing any of a try before.
    func upload(_ document: InvoiceDocument, clinicID: UUID) async throws
    /// `invoice_create`: the invoice for the uploaded pages, being read; the same invoice when it was created already.
    func create(_ document: InvoiceDocument, clinicID: UUID) async throws -> InvoiceSummary
    /// `extract_invoice`: asks the server to read the invoice; it answers at once and reads in the background.
    func startReading(invoiceID: UUID) async throws
    /// `invoice_detail`: the invoice as it stands, with its lines once read.
    func invoice(id: UUID) async throws -> InvoiceSummary
    /// Receive manually instead and Discard invoice: the invoice's pages are deleted from the invoices bucket, then
    /// `invoice_discard` sets the invoice aside.
    func discard(invoiceID: UUID, clinicID: UUID) async throws
}
