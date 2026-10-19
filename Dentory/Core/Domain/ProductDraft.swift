import Foundation

/// What the New / Edit product sheet saves (PRD §6.4, Appendix C `newProduct`): the fields of a product
/// an admin can type, with the quantities left to the receiving form.
nonisolated struct ProductDraft: Equatable, Sendable {
    var name: String
    var categoryID: UUID?
    /// The unit the product is counted in ("cartridges").
    var unit: String
    /// The unit it is received as ("box") and how many counted units one holds; both or neither.
    var packUnit: String?
    var packSize: Int?
    var tracking: TrackingMode
    var minimum: Decimal
    var target: Decimal
    var supplier: String?
    var location: String?
}
