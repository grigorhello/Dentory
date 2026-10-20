import Foundation
import Observation

/// Push notifications on this device (PRD §8, MS-144). After sign-in, a device iOS has not asked yet gets the
/// explainer once; "Turn on" shows the iOS prompt. Once allowed, each launch asks APNs for the device token and the
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
    private var isSignedIn = false
    /// The token APNs gave this launch, and the one the server holds for the signed-in member.
    private var deviceToken: String?
    private var registeredToken: String?

    init(authorizer: NotificationAuthorizing, repository: PushTokenRepository, store: PushExplainerStoring) {
        self.authorizer = authorizer
        self.repository = repository
        self.store = store
    }

    /// Admins also hear about deliveries ready to review; Staff do not get those (PRD §8).
    var explainerText: String {
        role == .admin
            ? "Get alerts for out-of-stock items, expiring stock and invoices ready to review."
            : "Get alerts for out-of-stock items and expiring stock."
    }

    /// The tabs just appeared for `session`: offer notifications once, or refresh the token when they are allowed.
    func signedIn(as session: Session) async {
        isSignedIn = true
        role = session.role
        switch await authorizer.permission() {
        case .notDetermined:
            guard !store.hasOffered else { return }
            // Offered counts at once, so a sheet swiped away is not offered again.
            store.hasOffered = true
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

    /// Before the session ends on this device: its pushes stop reaching this device. Offline, the server keeps the
    /// token until the next member who signs in here registers it as theirs.
    func signOut() async {
        isSignedIn = false
        isExplainerPresented = false
        pendingLink = nil
        guard let token = registeredToken else { return }
        registeredToken = nil
        try? await repository.remove(token: token)
    }

    /// Hands the token to the server once per member and token; a failure is retried at the next launch.
    private func upload() async {
        guard isSignedIn, let deviceToken, deviceToken != registeredToken else { return }
        do {
            try await repository.register(token: deviceToken)
            registeredToken = deviceToken
        } catch {
            registeredToken = nil
        }
    }
}
