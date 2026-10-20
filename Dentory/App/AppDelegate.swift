import UIKit
import UserNotifications

/// UIKit's half of push (MS-144): the APNs device token, a notification that arrives while the app is open (shown as
/// a banner), and a tapped one (its link opens). Anything that arrives before `DentoryApp` connects `push` waits.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var push: PushNotifications? {
        didSet { deliverWaiting() }
    }
    private var waitingToken: Data?
    private var waitingLink: NotificationLink?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard let push else {
            waitingToken = deviceToken
            return
        }
        Task { await push.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // No token this launch (a simulator without APNs, no network): the next launch asks again.
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let link = response.notification.request.content.userInfo["link"] as? String
        await opened(link)
    }

    private func opened(_ link: String?) {
        guard let link = link.flatMap(URL.init(string:)).flatMap(NotificationLink.init(url:)) else { return }
        guard let push else {
            waitingLink = link
            return
        }
        push.open(link)
    }

    private func deliverWaiting() {
        guard let push else { return }
        if let waitingToken {
            self.waitingToken = nil
            Task { await push.didRegister(deviceToken: waitingToken) }
        }
        if let waitingLink {
            self.waitingLink = nil
            push.open(waitingLink)
        }
    }
}
