import Foundation

/// Reads one product for Product detail, puts it on the To buy list (MS-116), adjusts its quantity with a
/// reason (MS-118) and opens or finishes its bottles (MS-120). Stock itself only moves through the engine
/// RPCs, with an idempotency key.
protocol ProductDetailRepository: Sendable {
    /// `product_detail`: throws `AppError.notFound` for a product the caller cannot see or that is archived.
    func detail(productID: UUID) async throws -> ProductDetail
    /// Adds a To buy line with the suggested quantity and returns its id, for Undo.
    func addToBuy(clinicID: UUID, productID: UUID, quantity: Decimal, userID: UUID) async throws -> UUID
    /// Undo of `addToBuy`.
    func removeFromToBuy(itemID: UUID) async throws
    /// "Delete product": archives it, history kept, off the templates and the open To buy lines (Admin).
    func archiveProduct(id: UUID) async throws
    /// `stock_adjust`: sets the unopened quantity to `actualQuantity` with the reason (and the note for
    /// Other). Applied now, or queued while offline; the action id of an applied write serves Undo.
    func adjust(productID: UUID, actualQuantity: Decimal, reason: AdjustmentReason, note: String?) async throws
        -> WriteOutcome
    /// `undo_action`: reverses an adjustment within 10 seconds, by the person who made it (MS-100 D10).
    func undoAdjustment(actionID: UUID) async throws
    /// `batch_upsert` (MS-119): a new batch (`batchID` nil) dates undated stock first, anything beyond it is a
    /// Data correction; an existing batch takes the month, quantity and lot. Applied now or queued offline.
    func upsertBatch(
        productID: UUID, batchID: UUID?, expiryMonth: CalendarDay, quantity: Decimal, lot: String?
    ) async throws -> WriteOutcome
    /// `bottle_open`: moves one unopened bottle, syringe or kit to an open item under the current user.
    /// Refused with "Out of stock" when nothing is unopened.
    func openBottle(productID: UUID) async throws -> WriteOutcome
    /// `bottle_finish`: removes the open item.
    func finishBottle(openItemID: UUID) async throws -> WriteOutcome
}
