import Foundation

/// The parameters of `stock_procedure_edit`; the coordinator adds `p_idempotency_key`.
nonisolated struct ProcedureUsageEditParams: Encodable, Sendable {
    /// One element of `p_items`, read by the function as `product_id` and `qty`.
    nonisolated struct Item: Encodable, Sendable {
        let productId: UUID
        let qty: Decimal
    }

    let pEventId: UUID
    let pItems: [Item]
    let pTakeNew: [UUID]

    init(_ edit: ProcedureUsageEdit) {
        pEventId = edit.eventID
        pItems = edit.lines.map { Item(productId: $0.productID, qty: $0.quantity) }
        pTakeNew = edit.takeNew
    }
}
