import Foundation

/// The clinic's team (MS-138): the list every member reads, and the admin's invitations, role changes and removals.
protocol TeamRepository: Sendable {
    /// `team_members`: admins, then Staff, then the open invitations.
    func members(clinicID: UUID) async throws -> [TeamMember]
    /// `invite_member` (MS-112), which also resends: a fresh link replaces the old one. Throws
    /// `AppError.validation(field: "email", …)` for an address already on the team.
    func invite(clinicID: UUID, fullName: String, email: String, role: MembershipRole) async throws
    /// `team_set_role`. Throws `AppError.validation` with "A clinic needs at least one admin." for the last admin.
    func setRole(memberID: UUID, role: MembershipRole) async throws
    /// `team_remove`: Remove from clinic, or Revoke invitation.
    func remove(memberID: UUID) async throws
}
