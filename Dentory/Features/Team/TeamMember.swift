import Foundation

/// A person on the clinic's team, or an invitation still open (MS-138; `team_members`). An invitation has no account
/// yet, and often no name.
nonisolated struct TeamMember: Identifiable, Equatable, Codable, Sendable {
    enum Status: String, Codable, Sendable {
        case active
        case invited
    }

    /// The membership's id: what the role change and the removal name.
    let id: UUID
    let userID: UUID?
    let fullName: String
    let email: String
    let role: MembershipRole
    let status: Status
    let invitedAt: Date

    var isPending: Bool { status == .invited }

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case fullName, email, role, status, invitedAt
    }
}
