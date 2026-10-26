import Foundation

/// Delete invoice file (MS-146; PRD §9 Privacy: invoice images belong to the clinic and can be deleted by an admin): a
/// received invoice's photo or PDF goes from Storage; its lines, the stock received, the ledger and History stay. The
/// server refuses anyone but an admin of the clinic, a read-only clinic (MS-142) and an invoice not received.
protocol InvoiceFileRepository: Sendable {
    /// `invoice_file_delete` lets go of the file, keeping who and when, then the pages are deleted from the invoices
    /// bucket, which refuses that while a received invoice holds them. Answers the invoice as it then stands:
    /// `hasFile` is false once no page is left.
    func deleteFile(invoiceID: UUID, clinicID: UUID) async throws -> InvoiceSummary
}
