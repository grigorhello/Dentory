import Foundation

/// The parameters of `procedure_template_save`. A new template sends `p_template_id` as null rather than leaving it
/// out, so PostgREST always finds the function by its full parameter list.
nonisolated struct ProcedureTemplateSaveParams: Encodable, Sendable {
    /// One element of `p_items`, read by the function as `product_id` and `default_qty`.
    nonisolated struct Item: Encodable, Sendable {
        let productId: UUID
        let defaultQty: Int
    }

    let pClinicId: UUID
    let pTemplateId: UUID?
    let pName: String
    let pItems: [Item]

    private enum CodingKeys: String, CodingKey {
        case pClinicId, pTemplateId, pName, pItems
    }

    init(_ request: ProcedureTemplateSaveRequest) {
        pClinicId = request.clinicID
        pTemplateId = request.templateID
        pName = request.name
        pItems = request.lines.map { Item(productId: $0.productID, defaultQty: $0.defaultQuantity) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pClinicId, forKey: .pClinicId)
        try container.encode(pTemplateId, forKey: .pTemplateId)
        try container.encode(pName, forKey: .pName)
        try container.encode(pItems, forKey: .pItems)
    }
}
