import Foundation

/// What `team_set_role` takes.
nonisolated struct TeamRoleParams: Encodable, Sendable {
    let pMembershipId: UUID
    let pRole: MembershipRole
}
