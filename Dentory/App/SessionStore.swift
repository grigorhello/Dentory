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

    private(set) var state: State = .restoring {
        didSet { if state != oldValue { followInAnalytics() } }
    }
    private(set) var lastError: AppError?
    /// Set when a stored session turned out to have no membership; Sign in shows the toast once.
    private(set) var accessWasRevoked = false

    private let auth: AuthServicing
    private let now: () -> Date
    /// Clears what the clinic left on the device (cached answers, writes waiting for a connection) when the server
    /// signs the member out here, as Sign out does (MS-137), so the next person neither sees nor sends them (MS-138).
    private let clearDevice: () async -> Void
    /// When the server last vouched for the signed-in member: restore, sign in or a check (MS-138).
    private var lastChecked: Date?
    private let analytics: Analytics
    /// The member analytics knows this device as, so that another member's session starts a new identity.
    private var identifiedUserID: UUID?

    init(
        auth: AuthServicing, state: State = .restoring, now: @escaping () -> Date = Date.init,
        clearDevice: @escaping () async -> Void = {}, analytics: Analytics = NoopAnalytics()
    ) {
        self.auth = auth
        self.state = state
        self.now = now
        self.clearDevice = clearDevice
        self.analytics = analytics
    }

    /// Analytics follows the member (MS-147): who is signed in, with their role and clinic, or nobody once signed out.
    /// A link that signs another member in over this one (an invitation, a password reset) starts a new identity
    /// first, so their events never go out under the previous member's id; a changed role keeps it.
    private func followInAnalytics() {
        switch state {
        case .signedIn(let session):
            if let identifiedUserID, identifiedUserID != session.userID { analytics.reset() }
            identifiedUserID = session.userID
            analytics.identify(session)
        case .signedOut:
            identifiedUserID = nil
            analytics.reset()
        case .restoring, .needsClinic:
            break
        }
    }

    var session: Session? {
        if case .signedIn(let session) = state { return session }
        return nil
    }

    /// The address of the account on this device, signed in or still without a clinic; nil when signed out.
    var accountEmail: String? {
        switch state {
        case .signedIn(let session): session.email
        case .needsClinic(let account): account.email
        case .signedOut, .restoring: nil
        }
    }

    /// Whether signing `email` in here would change the account on this device: a link that does so (an invitation, a
    /// password reset) runs Sign out's clean-up first, so the previous member's cached answers, queued writes, count
    /// in progress and push token never carry over to the next one (security review F4).
    func holdsAnotherAccount(than email: String) -> Bool {
        guard let accountEmail else { return false }
        return accountEmail.caseInsensitiveCompare(email) != .orderedSame
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
            if accessWasRevoked { await clearDevice() }
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
            await clearDevice()
            state = .signedOut
        case .failure(let error):
            guard AppError(error) == .forbidden else { return }
            lastError = .forbidden
            accessWasRevoked = true
            await clearDevice()
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
