import Foundation

/// What `expiring_batches` answers: the window it used (the clinic's largest expiry threshold when none is asked
/// for, MS-100 D8) and every batch expiring within it, expired ones first, soonest first.
nonisolated struct ExpiringList: Codable, Equatable, Sendable {
    let window: Int
    let batches: [ExpiringBatch]
}
