@testable import Dentory

/// The system's permission as a test sets it; counts the prompts and the token requests.
@MainActor
final class FakeNotificationAuthorizer: NotificationAuthorizing {
    var current: NotificationPermission
    var allows: Bool
    private(set) var prompts = 0
    private(set) var registrations = 0

    init(_ current: NotificationPermission = .notDetermined, allows: Bool = true) {
        self.current = current
        self.allows = allows
    }

    func permission() async -> NotificationPermission { current }

    func requestPermission() async -> Bool {
        prompts += 1
        current = allows ? .allowed : .denied
        return allows
    }

    func registerForRemoteNotifications() {
        registrations += 1
    }
}
