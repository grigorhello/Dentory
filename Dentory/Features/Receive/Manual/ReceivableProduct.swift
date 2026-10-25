import Foundation

/// A product Receive manually can receive (f24, Appendix C `pickProduct`), as `receive_products` answers it: what the
/// form needs to turn a delivery into stock (the unit it is counted in, the pack it is received in and that pack's
/// size, how it is tracked) and its stock. Decoded with the client's decoder (`JSONDecoder.supabase`, snake_case keys)
/// and cached with its encoder.
nonisolated struct ReceivableProduct: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let categoryName: String?
    /// The unit it is counted in, as typed on New product ("cartridges").
    let unit: String
    /// The pack it is received in ("box") and how many counted units one holds; both nil when it comes by the unit.
    let packUnit: String?
    let packSize: Int?
    let tracking: TrackingMode
    /// Unopened plus, for a multi-use product, the open ones.
    let quantity: Decimal
    let unopened: Decimal
    let openCount: Int

    /// The pack a delivery counts in, when the product has one: "box" holding 50 cartridges.
    var pack: (unit: String, size: Int)? {
        guard let packUnit, !packUnit.isEmpty, let packSize, packSize > 1 else { return nil }
        return (packUnit, packSize)
    }

    /// What a delivery adds to: the unopened ones of a multi-use product, whose received units arrive unopened (PRD
    /// §6.5; Low counts unopened only, MS-100 G3), else the quantity.
    var currentStock: Decimal {
        tracking == .multiUse ? unopened : quantity
    }

    /// A delivery in counted units: 5 boxes of 50 are 250 cartridges.
    func countedQuantity(received: Decimal) -> Decimal {
        received * Decimal(pack?.size ?? 1)
    }

    /// The cost per counted unit for a cost per received unit, to the four decimals a last unit cost keeps: $49.80 a
    /// box of 50 is $0.996 a cartridge.
    func unitCost(perReceived cost: Decimal) -> Decimal {
        var perUnit = cost / Decimal(pack?.size ?? 1)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &perUnit, 4, .plain)
        return rounded
    }
}
