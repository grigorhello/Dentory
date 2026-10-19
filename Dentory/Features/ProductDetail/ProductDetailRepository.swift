import Foundation

/// Reads one product for Product detail, puts it on the To buy list (MS-116) and adjusts its quantity with
/// a reason (MS-118). Stock itself only moves through the engine RPCs, with an idempotency key.
protocol ProductDetailRepository: Sendable {
    /// `product_detail`: throws `AppError.notFound` for a product the caller cannot see or that is archived.
    func detail(productID: UUID) async throws -> ProductDetail
    /// Adds a To buy line with the suggested quantity and returns its id, for Undo.
    func addToBuy(clinicID: UUID, productID: UUID, quantity: Decimal, userID: UUID) async throws -> UUID
    /// Undo of `addToBuy`.
    func removeFromToBuy(itemID: UUID) async throws
    /// `stock_adjust`: sets the unopened quantity to `actualQuantity` with the reason (and the note for
    /// Other). Applied now, or queued while offline; the action id of an applied write serves Undo.
    func adjust(productID: UUID, actualQuantity: Decimal, reason: AdjustmentReason, note: String?) async throws
        -> WriteOutcome
    /// `undo_action`: reverses an adjustment within 10 seconds, by the person who made it (MS-100 D10).
    func undoAdjustment(actionID: UUID) async throws
}
