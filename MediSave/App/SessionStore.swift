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
    }

    private(set) var state: State = .restoring
    private(set) var lastError: AppError?
    /// Set when a stored session turned out to have no membership; Sign in shows the toast once.
    private(set) var accessWasRevoked = false

    private let auth: AuthServicing

    init(auth: AuthServicing, state: State = .restoring) {
        self.auth = auth
        self.state = state
    }

    var session: Session? {
        if case .signedIn(let session) = state { return session }
        return nil
    }

    func restore() async {
        do {
            state = try await auth.restore().map(State.signedIn) ?? .signedOut
        } catch {
            lastError = AppError(error)
            accessWasRevoked = lastError == .forbidden
            state = .signedOut
        }
    }

    /// The Sign in screen calls this after showing the revoked toast.
    func acknowledgeRevokedAccess() {
        accessWasRevoked = false
    }

    func signIn(email: String, password: String) async -> Bool {
        lastError = nil
        do {
            state = .signedIn(try await auth.signIn(email: email, password: password))
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
