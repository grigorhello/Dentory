import Foundation

/// Review invoice (MS-129): the upload, the invoice row, the reading and its progress. Admin only; the server refuses
/// anyone else, and a read-only clinic's writes.
protocol InvoiceRepository: Sendable {
    /// Flow step 1: the pages to `invoices/{clinic_id}/{invoice_id}/page-n.(jpg|pdf)`, replacing any of a try before.
    func upload(_ document: InvoiceDocument, clinicID: UUID) async throws
    /// `invoice_create`: the invoice for the uploaded pages, being read; the same invoice when it was created already.
    func create(_ document: InvoiceDocument, clinicID: UUID) async throws -> InvoiceSummary
    /// `extract_invoice`: asks the server to read the invoice; it answers at once and reads in the background.
    func startReading(invoiceID: UUID) async throws
    /// `invoice_detail`: the invoice as it stands.
    func invoice(id: UUID) async throws -> InvoiceSummary
    /// `invoice_discard`: sets the invoice aside (Receive manually instead).
    func discard(invoiceID: UUID) async throws
}
