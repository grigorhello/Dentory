import Foundation
import Observation

/// The signed-in state the UI switches on. `restore()` runs once at launch; MS-110 drives `signIn`.
@MainActor
@Observable
final class SessionStore {
    enum State: Equatable {
        case restoring
        case signedOut
        case signedIn(Session)
        /// Signed up without a clinic yet: admin sign-up resumes at the clinic step (MS-111).
        case needsClinic(Account)
    }

    private(set) var state: State = .restoring
    private(set) var lastError: AppError?
    /// Set when a stored session turned out to have no membership; Sign in shows the toast once.
    private(set) var accessWasRevoked = false

    private let auth: AuthServicing
    private let now: () -> Date
    /// When the server last vouched for the signed-in member: restore, sign in or a check (MS-138).
    private var lastChecked: Date?

    init(auth: AuthServicing, state: State = .restoring, now: @escaping () -> Date = Date.init) {
        self.auth = auth
        self.state = state
        self.now = now
    }

    var session: Session? {
        if case .signedIn(let session) = state { return session }
        return nil
    }

    func restore() async {
        lastChecked = now()
        do {
            switch try await auth.restore() {
            case .none: state = .signedOut
            case .signedIn(let session): state = .signedIn(session)
            case .needsClinic(let account): state = .needsClinic(account)
            }
        } catch {
            lastError = AppError(error)
            accessWasRevoked = lastError == .forbidden
            state = .signedOut
        }
    }

    /// Checks the signed-in member against the server again (MS-138): a changed role shows at once, and someone removed
    /// from the clinic is signed out, with the revoked-access toast on Sign in. Offline, the session stays as it is.
    func revalidate() async {
        guard case .signedIn(let current) = state else { return }
        lastChecked = now()
        let answer: Result<RestoredSession, Error>
        do {
            answer = .success(try await auth.restore())
        } catch {
            answer = .failure(error)
        }
        // Signed out, or changed by another check, while this one waited: its answer is stale.
        guard state == .signedIn(current) else { return }
        switch answer {
        case .success(.signedIn(let session)):
            if session != current { state = .signedIn(session) }
        case .success(.none), .success(.needsClinic):
            state = .signedOut
        case .failure(let error):
            guard AppError(error) == .forbidden else { return }
            lastError = .forbidden
            accessWasRevoked = true
            state = .signedOut
        }
    }

    /// The same check as a screen loads, at most once a minute, so a removed member is signed out on their next request
    /// without a check for every one (MS-138).
    func revalidateIfDue() async {
        if let lastChecked, now().timeIntervalSince(lastChecked) < Self.checkInterval { return }
        await revalidate()
    }

    static let checkInterval: TimeInterval = 60

    /// After admin sign-up step 1: the user exists, the clinic does not yet.
    func didSignUp(_ account: Account) {
        state = .needsClinic(account)
    }

    /// After the clinic exists: reload the session from the server.
    func refresh() async {
        await restore()
    }

    /// The Sign in screen calls this after showing the revoked toast.
    func acknowledgeRevokedAccess() {
        accessWasRevoked = false
    }

    func signIn(email: String, password: String) async -> Bool {
        lastError = nil
        do {
            state = .signedIn(try await auth.signIn(email: email, password: password))
            lastChecked = now()
            return true
        } catch {
            lastError = AppError(error)
            return false
        }
    }

    func signOut() async {
        do {
            try await auth.signOut()
        } catch {
            lastError = AppError(error)
        }
        state = .signedOut
    }
}
