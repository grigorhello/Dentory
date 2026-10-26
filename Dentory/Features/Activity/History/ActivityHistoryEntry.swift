import Foundation

/// One row of Activity's History (PRD §6.8, f9), as `activity_history` returns it: a ledger row, or a procedure's
/// start, edit or cancellation as one row with its deltas summed; a receipt names the invoice it came from (MS-131).
/// Decoded with the client's decoder (`JSONDecoder.supabase`, snake_case keys) and cached with its encoder.
nonisolated struct ActivityHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    /// The ledger row's id, or the action's for a procedure's row.
    let id: UUID
    let at: Date
    let type: TransactionType
    /// The product, or the procedure's name for a procedure's row.
    let subject: String
    /// Nil for a procedure's row, which spans its products.
    let productID: UUID?
    let delta: Decimal
    /// What a count found against what was recorded; nil for anything else and for a procedure's row.
    let qtyBefore: Decimal?
    let qtyAfter: Decimal?
    /// `invoice`, `procedure_event`, `count_session`, `manual` or `undo`.
    let refType: String
    let refLabel: String?
    let reason: String?
    let note: String?
    /// A procedure's row that edited its usage rather than starting it.
    let isEdit: Bool
    /// The member's full name; empty when they have left the clinic.
    let byName: String
    /// The invoice a receipt came from, which an admin opens from History (MS-131); nil for any other row, and in an
    /// answer cached before the server named it.
    var invoiceID: UUID?

    private enum CodingKeys: String, CodingKey {
        case id, at, type, subject, productID = "productId", delta, qtyBefore, qtyAfter, refType, refLabel, reason,
             note, isEdit, byName, invoiceID = "invoiceId"
    }
}
