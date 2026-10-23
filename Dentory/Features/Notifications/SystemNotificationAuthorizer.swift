import UIKit
import UserNotifications

/// `UNUserNotificationCenter` and `UIApplication` behind `NotificationAuthorizing`.
struct SystemNotificationAuthorizer: NotificationAuthorizing {
    func permission() async -> NotificationPermission {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .allowed
        }
    }

    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}
