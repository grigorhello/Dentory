import Foundation

/// Everything Product detail shows (PRD §6.4), as `product_detail` reports it: the product with its figures
/// and status, what procedures used in the last 30 days, the last count, the To buy state, the batches,
/// the open bottles and the last 20 ledger rows.
nonisolated struct ProductDetail: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let categoryName: String?
    /// The unit the product is counted in ("cartridges").
    let unit: String
    /// The pack it is received in ("box") and how many units one holds; nil when it is received by the unit.
    let packUnit: String?
    let packSize: Int?
    let minimum: Decimal
    let target: Decimal
    let tracking: TrackingMode
    let location: String?
    let status: ProductStatus
    /// Unopened plus, for multi-use products, the open ones.
    let quantity: Decimal
    let unopened: Decimal
    let openCount: Int
    let missingExpiryQuantity: Decimal
    /// What procedures deducted in the last 30 days.
    let usedInLast30Days: Decimal
    /// When the last count was applied; nil when the product was never counted.
    let lastCountedAt: Date?
    /// The open To buy line for the product, when there is one.
    let toBuyItemID: UUID?
    let batches: [ProductBatch]
    let openBottles: [OpenBottle]
    /// Newest first, at most 20.
    let history: [StockTransaction]
    /// What the Edit product sheet starts from besides the fields above (MS-117).
    var categoryID: UUID?
    var supplier: String?

    /// The same product with `delta` added to its quantity and unopened count (an increase lands on the
    /// undated quantity, MS-100 D9) and the given history. Status is left to the server's next answer.
    func adjusted(by delta: Decimal, history: [StockTransaction]) -> ProductDetail {
        replacing(quantity: quantity + delta, unopened: unopened + delta, history: history)
    }

    /// The same product with the open bottles replaced: the quantity stays (an open one still counts), the
    /// unopened count moves by `unopenedDelta` (−1 when one was opened, 0 when one was finished).
    func replacingBottles(_ bottles: [OpenBottle], unopenedDelta: Decimal, quantityDelta: Decimal) -> ProductDetail {
        replacing(quantity: quantity + quantityDelta, unopened: unopened + unopenedDelta, openBottles: bottles)
    }

    /// A copy with some figures replaced; the open count follows the open bottles.
    func replacing(
        quantity: Decimal? = nil,
        unopened: Decimal? = nil,
        openBottles: [OpenBottle]? = nil,
        history: [StockTransaction]? = nil
    ) -> ProductDetail {
        ProductDetail(
            id: id, name: name, categoryName: categoryName, unit: unit, packUnit: packUnit, packSize: packSize,
            minimum: minimum, target: target, tracking: tracking, location: location, status: status,
            quantity: quantity ?? self.quantity, unopened: unopened ?? self.unopened,
            openCount: openBottles?.count ?? openCount, missingExpiryQuantity: missingExpiryQuantity,
            usedInLast30Days: usedInLast30Days, lastCountedAt: lastCountedAt, toBuyItemID: toBuyItemID,
            batches: batches, openBottles: openBottles ?? self.openBottles, history: history ?? self.history,
            categoryID: categoryID, supplier: supplier
        )
    }
}

/// A batch of the product: a quantity with an expiry month and a lot, or undated.
nonisolated struct ProductBatch: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    /// The first day of the expiry month; nil for the undated quantity (Missing expiry).
    let expiryMonth: CalendarDay?
    let lot: String?
    let quantity: Decimal
}

/// A bottle, syringe or kit someone opened and has not finished.
nonisolated struct OpenBottle: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let openedAt: Date
    let openedByName: String
}

/// One ledger row of the product.
nonisolated struct StockTransaction: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let type: TransactionType
    let delta: Decimal
    let quantityBefore: Decimal
    let quantityAfter: Decimal
    /// The adjustment reason ("Damaged") or the count's "Physical count".
    let reason: String?
    /// What the row refers to: the procedure's name, the invoice.
    let referenceLabel: String?
    let at: Date
    let byName: String
}
