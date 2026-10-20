import Foundation

/// One of the highest value products (f10): what it holds, its last unit cost and the product of the two.
nonisolated struct InventoryValueProduct: Codable, Equatable, Identifiable, Sendable {
    let productID: UUID
    let name: String
    let unit: String
    let quantity: Decimal
    let unitCost: Decimal
    let value: Decimal

    var id: UUID { productID }

    private enum CodingKeys: String, CodingKey {
        case productID = "productId", name, unit, quantity, unitCost, value
    }
}
