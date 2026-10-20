import Foundation

/// Reads what Account shows beyond the session (MS-137).
protocol AccountRepository: Sendable {
    /// The clinic's active members, "3 people" on the Team row; pending invitations are left out.
    func teamSize(clinicID: UUID) async throws -> Int
}
