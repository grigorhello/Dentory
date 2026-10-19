import Foundation

/// One supply of a template: the product, its default quantity, and the stock it takes from. A countable product
/// takes from its quantity; a multi-use product uses an open one or takes a new one from its unopened count.
nonisolated struct ProcedureTemplateItem: Codable, Equatable, Identifiable, Sendable {
    /// The product's id.
    let id: UUID
    let name: String
    /// The unit the product is counted in ("cartridges").
    let unit: String
    let tracking: TrackingMode
    /// The template's quantity; 0 for a multi-use product, whose open one is used.
    let defaultQty: Decimal
    let quantity: Decimal
    let unopened: Decimal
    let openCount: Int
}
