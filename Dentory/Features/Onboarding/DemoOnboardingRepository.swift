import Foundation

/// Creates a demo clinic without a server: previews and UI tests sign up through it.
final class DemoOnboardingRepository: OnboardingRepository, @unchecked Sendable {
    private let auth: PreviewAuthService
    private(set) var invited: [TeamInvite] = []

    init(auth: PreviewAuthService) {
        self.auth = auth
    }

    func createClinic(
        name: String, city: String, country: String, timeZone: String, fullName: String
    ) async throws -> UUID {
        try await Task.sleep(for: .milliseconds(300))
        let session = Session(
            userID: Session.demo.userID, email: auth.account?.email ?? Session.demo.email, fullName: fullName,
            clinicID: Session.demo.clinicID, clinicName: name, role: .admin,
            currency: country == "CA" ? "CAD" : "USD", timeZone: timeZone
        )
        auth.session = session
        return session.clinicID
    }

    func uploadLogo(clinicID: UUID, imageData: Data) async throws {}

    func invite(clinicID: UUID, invites: [TeamInvite]) async throws -> Int {
        try await Task.sleep(for: .milliseconds(200))
        invited += invites
        return invites.count
    }
}
