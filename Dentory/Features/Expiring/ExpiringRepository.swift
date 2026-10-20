import Foundation

/// Expiring soon (MS-132): the batches expiring within the clinic's window, and Mark disposed with its Undo, both
/// through the write queue of MS-108.
protocol ExpiringRepository: Sendable {
    /// `expiring_batches` with the clinic's own window, the largest of its expiry thresholds.
    func batches(clinicID: UUID) async throws -> ExpiringList

    /// `stock_dispose`: takes `quantity` out of the batch with the reason Expired (Admin only).
    func dispose(batchID: UUID, quantity: Decimal) async throws -> WriteOutcome

    /// `undo_action`: puts a disposal back within 10 seconds, by the person who made it (MS-100 D10).
    func undoDisposal(actionID: UUID) async throws
}
