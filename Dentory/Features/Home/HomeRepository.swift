import Foundation

/// Reads what Home shows for one clinic and one user.
protocol HomeRepository: Sendable {
    func summary(clinicID: UUID, userID: UUID) async throws -> HomeSummary
}
