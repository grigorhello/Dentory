import Foundation

/// To buy (MS-128): the list, the products Add item offers, and the changes both roles make; Mark as ordered is
/// the admin's. The list is a shopping list: nothing here places an order.
protocol ToBuyRepository: Sendable {
    /// `to_buy_list`: to buy, ordered, and received in the last 90 days.
    func items(clinicID: UUID) async throws -> [ToBuyItem]

    /// `inventory_list`: the products Add item offers.
    func products(clinicID: UUID) async throws -> [ProductSummary]

    /// `to_buy_add`: the product joins with target − current, at least 1. Answers the line.
    func add(clinicID: UUID, productID: UUID) async throws -> AddedToBuy

    /// A quantity someone set; it no longer follows stock.
    func setQuantity(itemID: UUID, quantity: Decimal) async throws

    /// Takes a line off the list (the swipe, or Undo of Add item).
    func remove(itemID: UUID) async throws

    /// `to_buy_mark_ordered`: the lines move to Ordered with today's date. Answers how many moved.
    func markOrdered(clinicID: UUID, itemIDs: [UUID]) async throws -> Int
}
