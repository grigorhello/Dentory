import Foundation

/// The parameters of `invoice_confirm` (MS-131); the coordinator adds `p_idempotency_key`, which a replay of the same
/// confirmation keeps, so the delivery is received once.
nonisolated struct InvoiceConfirmParams: Encodable, Sendable {
    let pInvoiceId: UUID
}
