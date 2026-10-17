import Foundation

/// Everything Home shows (PRD §6.2): the attention counts and values of `clinic_attention`, the latest
/// procedure, and whether the user has alerts they have not seen.
nonisolated struct HomeSummary: Codable, Equatable, Sendable {
    let toBuyCount: Int
    let expiringBatchCount: Int
    let missingExpiryProductCount: Int
    let inventoryValue: Decimal
    let valueAtRisk90: Decimal
    let latestProcedure: LatestProcedure?
    let hasUnseenAlerts: Bool
}

/// The most recent procedure that was not cancelled.
nonisolated struct LatestProcedure: Codable, Equatable, Sendable {
    /// The procedure event's id.
    let id: UUID
    let name: String
    let startedAt: Date
    let supplyCount: Int
    /// First name of who started it ("Sarah"); empty when the membership is gone.
    let startedByFirstName: String
}
