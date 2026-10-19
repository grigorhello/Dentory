import Foundation

/// A fixed invitation for previews and UI tests: `demo-invite` joins Smile Dental as Staff, any other token
/// reads as expired. Accepting registers the address with `PreviewAuthService`, so the sign-in that
/// follows works without a server.
final class DemoInvitationRepository: InvitationRepository, @unchecked Sendable {
    static let validToken = "demo-invite"
    static let email = "priya@smiledental.ca"

    private let auth: PreviewAuthService
    private(set) var accepted: [String] = []

    init(auth: PreviewAuthService) {
        self.auth = auth
    }

    func invitation(token: String) async throws -> Invitation? {
        try await Task.sleep(for: .milliseconds(300))
        guard token == Self.validToken else { return nil }
        return Invitation(
            clinicName: "Smile Dental",
            invitedByName: "Sarah Mitchell",
            role: .staff,
            email: Self.email,
            fullName: "",
            expiresAt: Session.demoNow.addingTimeInterval(6 * 86_400)
        )
    }

    func accept(token: String, fullName: String, password: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
        guard token == Self.validToken else { throw AppError.notFound }
        let session = Session(
            userID: UUID(uuidString: "00000000-0000-4000-8000-0000000000a4") ?? UUID(),
            email: Self.email,
            fullName: fullName,
            clinicID: Session.demo.clinicID,
            clinicName: "Smile Dental",
            role: .staff,
            currency: "USD",
            timeZone: "America/New_York"
        )
        auth.register(email: Self.email, password: password, session: session)
        accepted.append(token)
    }
}
