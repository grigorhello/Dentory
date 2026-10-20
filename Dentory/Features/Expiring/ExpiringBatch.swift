import Foundation

/// One batch on Expiring soon (PRD §6.7, f27): the product, what the batch holds, its lot and expiry month, and
/// what it is worth at the product's last unit cost, as `expiring_batches` reports it. Decoded with the client's
/// decoder (`JSONDecoder.supabase`, snake_case keys) and cached with its encoder.
nonisolated struct ExpiringBatch: Codable, Equatable, Identifiable, Sendable {
    /// The batch's id.
    let id: UUID
    let productID: UUID
    let name: String
    /// The unit the product is counted in ("cartridges"); a multi-use product's batch holds unopened bottles.
    let unit: String
    let tracking: TrackingMode
    let quantity: Decimal
    let lot: String?
    /// The month the batch expires; it expires on the month's last day.
    let expiryMonth: CalendarDay
    let value: Decimal

    private enum CodingKeys: String, CodingKey {
        case id, productID = "productId", name, unit, tracking, quantity = "qty", lot, expiryMonth, value
    }

    /// The same batch after `disposed` of it was disposed.
    func disposing(_ disposed: Decimal) -> ExpiringBatch {
        let left = max(quantity - disposed, 0)
        let unitValue = quantity > 0 ? value / quantity : 0
        return ExpiringBatch(
            id: id, productID: productID, name: name, unit: unit, tracking: tracking, quantity: left, lot: lot,
            expiryMonth: expiryMonth, value: unitValue * left
        )
    }
}
