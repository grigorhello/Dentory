import Foundation

extension Session {
    /// October 2, 2026, 9:41 in New York, the moment every frame shows (the frames label it a Thursday; it is a Friday).
    nonisolated static let demoNow = Date(timeIntervalSince1970: 1_790_933_260)

    nonisolated static let demo = demo(role: .admin)

    /// Sarah (Admin) or Michael (Staff) of the demo clinic (MS-109).
    nonisolated static func demo(role: MembershipRole) -> Session {
        Session(
            userID: UUID(uuidString: "00000000-0000-4000-8000-0000000000a1") ?? UUID(),
            email: role == .admin ? "sarah@smiledental.ca" : "michael@smiledental.ca",
            fullName: role == .admin ? "Sarah Mitchell" : "Michael Reyes",
            clinicID: UUID(uuidString: "00000000-0000-4000-8000-000000000001") ?? UUID(),
            clinicName: "Smile Dental",
            role: role,
            currency: "USD",
            timeZone: "America/New_York"
        )
    }
}
