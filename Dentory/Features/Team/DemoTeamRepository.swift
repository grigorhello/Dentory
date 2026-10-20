import Foundation

/// The team without a server: f31's people (Sarah and Dr. Daniel Kim as admins, Michael as Staff, Priya invited on
/// Oct 1), changed in memory as the server would, the last admin kept and an address on the team refused.
final class DemoTeamRepository: TeamRepository, @unchecked Sendable {
    private var team: [TeamMember]
    private let lock = NSLock()

    init(team: [TeamMember] = TeamMember.demo) {
        self.team = team
    }

    func members(clinicID: UUID) async throws -> [TeamMember] {
        try await Task.sleep(for: .milliseconds(150))
        return lock.withLock { Self.ordered(team) }
    }

    func invite(clinicID: UUID, fullName: String, email: String, role: MembershipRole) async throws {
        try await Task.sleep(for: .milliseconds(300))
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        try lock.withLock {
            if team.contains(where: { $0.email == address && !$0.isPending }) {
                throw AppError.validation(field: "email", message: "\(address) is already on the team")
            }
            let invited = TeamMember(
                id: UUID(), userID: nil, fullName: fullName, email: address, role: role, status: .invited,
                invitedAt: Session.demoNow
            )
            team.removeAll { $0.email == address }
            team.append(invited)
        }
    }

    func setRole(memberID: UUID, role: MembershipRole) async throws {
        try await Task.sleep(for: .milliseconds(200))
        try lock.withLock {
            guard let index = team.firstIndex(where: { $0.id == memberID }) else { throw AppError.notFound }
            try keepAnAdmin(without: memberID, unless: role == .admin)
            let member = team[index]
            team[index] = TeamMember(
                id: member.id, userID: member.userID, fullName: member.fullName, email: member.email, role: role,
                status: member.status, invitedAt: member.invitedAt
            )
        }
    }

    func remove(memberID: UUID) async throws {
        try await Task.sleep(for: .milliseconds(200))
        try lock.withLock {
            try keepAnAdmin(without: memberID, unless: false)
            team.removeAll { $0.id == memberID }
        }
    }

    /// Refuses a change that would leave no active admin, as `memberships_keep_an_admin` does.
    private func keepAnAdmin(without memberID: UUID, unless stillAdmin: Bool) throws {
        guard !stillAdmin else { return }
        let otherAdmins = team.filter { $0.role == .admin && !$0.isPending && $0.id != memberID }
        let isAdmin = team.contains { $0.id == memberID && $0.role == .admin && !$0.isPending }
        if isAdmin && otherAdmins.isEmpty {
            throw AppError.validation(field: nil, message: "A clinic needs at least one admin.")
        }
    }

    private static func ordered(_ team: [TeamMember]) -> [TeamMember] {
        team.sorted { lhs, rhs in
            let left = (lhs.isPending, lhs.role == .staff, lhs.invitedAt)
            let right = (rhs.isPending, rhs.role == .staff, rhs.invitedAt)
            if left.0 != right.0 { return !left.0 }
            if left.1 != right.1 { return !left.1 }
            return left.2 < right.2
        }
    }
}

extension TeamMember {
    /// f31: the demo clinic's people (`seed-demo.sql`); ids as the demo session's and the seed's.
    nonisolated static let demo: [TeamMember] = [
        demo(0xa1, user: 0xa1, "Sarah Mitchell", "sarah@smiledental.ca", .admin, joined: 1_783_155_600),
        demo(0xa2, user: 0xa2, "Dr. Daniel Kim", "daniel@smiledental.ca", .admin, joined: 1_783_157_400),
        demo(0xa3, user: 0xa3, "Michael Reyes", "michael@smiledental.ca", .staff, joined: 1_783_157_400),
        demo(0xa4, user: nil, "", "priya@smiledental.ca", .staff, joined: 1_790_863_200)
    ]

    // swiftlint:disable:next function_parameter_count
    private nonisolated static func demo(
        _ number: Int, user: Int?, _ name: String, _ email: String, _ role: MembershipRole, joined: TimeInterval
    ) -> TeamMember {
        TeamMember(
            id: demoID(number + 0xb00), userID: user.map(demoID), fullName: name, email: email, role: role,
            status: user == nil ? .invited : .active, invitedAt: Date(timeIntervalSince1970: joined)
        )
    }

    private nonisolated static func demoID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012x", number)) ?? UUID()
    }
}
