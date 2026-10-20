import Foundation

/// Reads what Home shows for one clinic and the signed-in member (whose bell dot it is).
protocol HomeRepository: Sendable {
    func summary(clinicID: UUID) async throws -> HomeSummary
}
