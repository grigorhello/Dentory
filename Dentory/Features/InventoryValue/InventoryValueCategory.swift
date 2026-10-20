import Foundation

/// One category's part of the inventory value (f10 By category). The products without a category come as one
/// group with no id and no name.
nonisolated struct InventoryValueCategory: Codable, Equatable, Identifiable, Sendable {
    let categoryID: UUID?
    let name: String?
    let value: Decimal
    let productCount: Int

    /// The category's id, lowercased as the element ids use it, or "none" for the products without a category.
    var id: String { categoryID?.uuidString.lowercased() ?? "none" }

    private enum CodingKeys: String, CodingKey {
        case categoryID = "categoryId", name, value, productCount
    }
}
