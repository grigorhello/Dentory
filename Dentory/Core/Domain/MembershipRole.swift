/// The two roles (PRD §2). Role gating hides controls; the database enforces the same table.
nonisolated enum MembershipRole: String, Codable, Sendable {
    case admin
    case staff

    /// The word the UI uses for the role (PRD §7 vocabulary).
    var label: String { self == .admin ? "Admin" : "Staff" }
}
