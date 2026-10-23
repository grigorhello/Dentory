import Foundation

/// One line of To buy (PRD §6.6): the product with its stock and target, the quantity to buy, and where the line
/// stands, as `to_buy_list` reports it. Decoded with the client's decoder (`JSONDecoder.supabase`, snake_case keys).
nonisolated struct ToBuyItem: Codable, Equatable, Identifiable, Sendable {
    nonisolated enum Status: String, Codable, Sendable {
        case toBuy = "to_buy"
        case ordered
        case received
    }

    /// Added by the stock rules when the product went Low or Out of stock, or by someone by hand.
    nonisolated enum Source: String, Codable, Sendable {
        case auto
        case manual
    }

    let id: UUID
    let productID: UUID
    let name: String
    /// The unit the product is counted in ("kits").
    let unit: String
    let supplier: String?
    /// Stock now: a countable product's quantity, a multi-use product's unopened and open together.
    let quantity: Decimal
    let target: Decimal
    /// How many to buy: target − current until someone changes it or the line is ordered.
    var buyQuantity: Decimal
    let source: Source
    let status: Status
    let createdAt: Date
    let orderedAt: Date?
    let receivedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, productID = "productId", name, unit, supplier, quantity, target, buyQuantity = "qty", source, status
        case createdAt, orderedAt, receivedAt
    }
}
