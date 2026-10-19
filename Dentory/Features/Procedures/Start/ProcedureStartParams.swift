import Foundation

/// The parameters of `stock_procedure_start`; the coordinator adds `p_idempotency_key`.
nonisolated struct ProcedureStartParams: Encodable, Sendable {
    /// One element of `p_items`, read by the function as `product_id` and `qty`.
    nonisolated struct Item: Encodable, Sendable {
        let productId: UUID
        let qty: Decimal
    }

    let pClinicId: UUID
    let pTemplateId: UUID
    let pName: String
    let pItems: [Item]
    let pTakeNew: [UUID]

    init(_ request: ProcedureStartRequest) {
        pClinicId = request.clinicID
        pTemplateId = request.templateID
        pName = request.name
        pItems = request.lines.map { Item(productId: $0.productID, qty: $0.quantity) }
        pTakeNew = request.takeNew
    }
}
