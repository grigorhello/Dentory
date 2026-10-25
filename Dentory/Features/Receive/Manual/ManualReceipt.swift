import Foundation

/// What Receive manually sends (`stock_receive` with one line, referenced as Receive manually): the delivery in counted
/// units, so 5 boxes of a 50-pack arrive as 250 cartridges, at the cost per counted unit.
nonisolated struct ManualReceipt: Equatable, Sendable {
    let clinicID: UUID
    let productID: UUID
    /// In counted units.
    let quantity: Decimal
    /// Per counted unit; nil keeps the product's last unit cost.
    let unitCost: Decimal?
    let lot: String?
    /// The first day of the expiry month; nil leaves the quantity undated (Missing expiry).
    let expiryMonth: CalendarDay?
}
