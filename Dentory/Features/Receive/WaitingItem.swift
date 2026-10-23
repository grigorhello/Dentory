import Foundation

/// A To buy line marked Ordered, listed under "Waiting for delivery" for reference only (f22): receiving the product
/// from its invoice moves it to Received.
nonisolated struct WaitingItem: Codable, Equatable, Identifiable, Sendable {
    /// The To buy line's id.
    let id: UUID
    let productID: UUID
    let name: String
    /// The unit the product is counted in ("needles"), which the quantity is in.
    let unit: String
    let supplier: String?
    let quantity: Decimal
    let orderedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, productID = "productId", name, unit, supplier, quantity = "qty", orderedAt
    }
}
