import Foundation
import Observation

/// Push notifications on this device (PRD §8, MS-144). After sign-in, a device iOS has not asked yet gets the
/// explainer; "Turn on" shows the iOS prompt, and "Not now" brings the explainer back 30 days later, since iOS shows no
/// Notifications setting for an app that never asked. Once allowed, each launch asks APNs for the device token and the
/// server keeps it for the signed-in member, until they sign out here. A tapped notification's link waits in
/// `pendingLink` for the root view to open.
@MainActor
@Observable
final class PushNotifications {
    var isExplainerPresented = false
    /// What a tapped notification opens; the root view clears it once open.
    var pendingLink: NotificationLink?
    private(set) var role: MembershipRole = .staff

    private let authorizer: NotificationAuthorizing
    private let repository: PushTokenRepository
    private let store: PushExplainerStoring
    private let now: () -> Date
    /// The member signed in on this device; nil once they sign out.
    private var memberID: UUID?
    /// The token APNs gave this launch.
    private var deviceToken: String?
    /// What the server holds: this device's token, for that member.
    private var registered: Registration?

    private struct Registration: Equatable {
        let token: String
        let memberID: UUID
    }

    init(
        authorizer: NotificationAuthorizing, repository: PushTokenRepository, store: PushExplainerStoring,
        now: @escaping () -> Date = Date.init
    ) {
        self.authorizer = authorizer
        self.repository = repository
        self.store = store
        self.now = now
    }

    /// How long "Not now" holds the explainer back.
    static let reofferInterval: TimeInterval = 30 * 24 * 60 * 60

    /// Admins also hear about deliveries ready to review; Staff do not get those (PRD §8).
    var explainerText: String {
        role == .admin
            ? "Get alerts for out-of-stock items, expiring stock and invoices ready to review."
            : "Get alerts for out-of-stock items and expiring stock."
    }

    /// The tabs just appeared for `session`: offer notifications, or refresh the token when they are allowed.
    func signedIn(as session: Session) async {
        memberID = session.userID
        role = session.role
        switch await authorizer.permission() {
        case .notDetermined:
            if let offered = store.lastOffered, now().timeIntervalSince(offered) < Self.reofferInterval { return }
            // Offered counts at once, so a sheet swiped away waits like Not now.
            store.lastOffered = now()
            isExplainerPresented = true
        case .allowed:
            authorizer.registerForRemoteNotifications()
            await upload()
        case .denied:
            break
        }
    }

    func turnOn() async {
        isExplainerPresented = false
        if await authorizer.requestPermission() {
            authorizer.registerForRemoteNotifications()
        }
    }

    func notNow() {
        isExplainerPresented = false
    }

    /// APNs answered `registerForRemoteNotifications` with this device's token.
    func didRegister(deviceToken: Data) async {
        self.deviceToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        await upload()
    }

    func open(_ link: NotificationLink) {
        pendingLink = link
    }

    /// Before the session ends on this device: its pushes stop reaching this device. The token goes even when this
    /// launch could not register it, since the server may hold it from an earlier launch; only the member's own row is
    /// removed. Offline, the server keeps it until the next member who signs in here registers it as theirs.
    func signOut() async {
        memberID = nil
        registered = nil
        isExplainerPresented = false
        pendingLink = nil
        guard let deviceToken else { return }
        try? await repository.remove(token: deviceToken)
    }

    /// Hands the token to the server once per member and token, so a device that changes hands without Sign out
    /// (joining from an invitation, a password reset) becomes the new member's. A failure is retried at the next launch.
    private func upload() async {
        guard let memberID, let deviceToken else { return }
        let registration = Registration(token: deviceToken, memberID: memberID)
        guard registration != registered else { return }
        do {
            try await repository.register(token: deviceToken)
            registered = registration
        } catch {
            registered = nil
        }
    }
}
