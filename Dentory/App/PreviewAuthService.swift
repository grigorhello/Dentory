import Foundation

/// Signs in the demo clinic's people with the seed password (MS-109); anything else is refused the
/// way Supabase would. Sign-up creates an account in memory; `DemoOnboardingRepository` then sets the session.
final class PreviewAuthService: AuthServicing, @unchecked Sendable {
    var session: Session?
    var account: Account?
    /// Accounts the demo invitation flow created: address to the password set and the session it yields.
    private var registered: [String: (password: String, session: Session)] = [:]
    /// The demo admin, signed in by a good reset link until the new password is saved (MS-113).
    private var recovering: Session?
    static let demoPassword = "smiledental"
    static let demoEmails = ["sarah@smiledental.ca", "michael@smiledental.ca"]
    /// The one reset link that works without a server; any other token hash reads as expired.
    static let demoResetToken = "demo-reset"

    init(session: Session?) {
        self.session = session
    }

    func restore() async throws -> RestoredSession {
        if let session { return .signedIn(session) }
        if let account { return .needsClinic(account) }
        return .none
    }

    func register(email: String, password: String, session: Session) {
        registered[email.lowercased()] = (password, session)
    }

    func signIn(email: String, password: String) async throws -> Session {
        try await Task.sleep(for: .milliseconds(400))
        if let account = registered[email.lowercased()] {
            guard password == account.password else { throw AppError.wrongPassword }
            session = account.session
            return account.session
        }
        guard Self.demoEmails.contains(email.lowercased()) else { throw AppError.unknownEmail }
        guard password == Self.demoPassword else { throw AppError.wrongPassword }
        return .demo
    }

    func signUp(fullName: String, email: String, password: String) async throws -> Account {
        try await Task.sleep(for: .milliseconds(300))
        guard !Self.demoEmails.contains(email.lowercased()) else { throw AppError.emailTaken }
        let account = Account(userID: UUID(), email: email, fullName: fullName)
        self.account = account
        return account
    }

    func signOut() async throws {
        session = nil
        account = nil
    }

    /// Like Supabase: the same answer for a known and an unknown address; only a malformed one is refused.
    func sendPasswordReset(email: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
        guard email.contains("@") else { throw AppError.invalidEmail }
    }

    func verifyPasswordReset(tokenHash: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
        guard tokenHash == Self.demoResetToken else { throw AppError.notFound }
        recovering = .demo
    }

    func updatePassword(_ password: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
        guard password.count >= 8 else { throw AppError.shortPassword }
        guard let recovering else { throw AppError.unknown("No reset in progress") }
        session = recovering
        self.recovering = nil
    }
}

extension PreviewAuthService {
    /// The demo admin or Staff member signed in, or no one; `-onboarding clinic` resumes admin sign-up at step 2 with
    /// a new account (screenshots).
    static func demo(signedIn: Bool, role: MembershipRole, onboarding: String?) -> PreviewAuthService {
        let auth = PreviewAuthService(session: signedIn ? Session.demo(role: role) : nil)
        if onboarding == "clinic" {
            auth.session = nil
            auth.account = Account(
                userID: Session.demo.userID, email: "owner@newclinic.ca", fullName: "Dr. Sarah Mitchell"
            )
        }
        return auth
    }
}
