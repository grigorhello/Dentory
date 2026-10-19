import Foundation

/// One row of the Inventory list (PRD §6.4): the product, its stock figures and its status, as
/// `inventory_list` reports them. Count mode (MS-121) and the procedure item picker (MS-123) read the same rows.
nonisolated struct ProductSummary: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let categoryName: String?
    /// The unit the product is counted in ("cartridges").
    let unit: String
    let tracking: TrackingMode
    let location: String?
    /// Unopened plus, for multi-use products, the open ones.
    let quantity: Decimal
    let unopened: Decimal
    let openCount: Int
    let minimum: Decimal
    let status: ProductStatus
}
