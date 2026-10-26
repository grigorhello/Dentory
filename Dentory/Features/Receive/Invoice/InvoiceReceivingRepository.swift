import Foundation

/// Confirm & receive (MS-131, Appendix B `invoice.confirm`): the reviewed delivery into stock as one engine action, and
/// its Undo. Both go through the write queue (MS-108), so a delivery confirmed offline is received once the device is
/// back online, with the same idempotency key. The server refuses anyone but an admin and a read-only clinic (MS-142),
/// an invoice no longer waiting for review, a line not resolved yet and a product deleted since its line was settled.
protocol InvoiceReceivingRepository: Sendable {
    /// `invoice_confirm`: applied now, answering the action Undo reverses, or queued while offline.
    func confirm(invoiceID: UUID) async throws -> WriteOutcome
    /// `undo_action` on the confirmation, by the admin who confirmed, within 10 seconds (MS-100 D10): the delivery goes
    /// back out of stock and the invoice waits for review again.
    func undoConfirm(actionID: UUID) async throws
}
