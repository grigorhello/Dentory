import Foundation
@testable import Dentory

/// The team as a test sets it; records each call and throws `failure` when set.
final class FakeTeamRepository: TeamRepository, @unchecked Sendable {
    var team: [TeamMember] = TeamMember.demo
    var membersFailure: Error?
    var failure: Error?
    struct Invite: Equatable {
        let fullName: String
        let email: String
        let role: MembershipRole
    }

    private(set) var loads = 0
    private(set) var invites: [Invite] = []
    private(set) var roleChanges: [(UUID, MembershipRole)] = []
    private(set) var removals: [UUID] = []

    func members(clinicID: UUID) async throws -> [TeamMember] {
        loads += 1
        if let membersFailure { throw membersFailure }
        return team
    }

    func invite(clinicID: UUID, fullName: String, email: String, role: MembershipRole) async throws {
        if let failure { throw failure }
        invites.append(Invite(fullName: fullName, email: email, role: role))
    }

    func setRole(memberID: UUID, role: MembershipRole) async throws {
        if let failure { throw failure }
        roleChanges.append((memberID, role))
    }

    func remove(memberID: UUID) async throws {
        if let failure { throw failure }
        removals.append(memberID)
    }
}
