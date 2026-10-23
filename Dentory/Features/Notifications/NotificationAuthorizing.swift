/// The system's side of push (MS-144): the permission, the iOS prompt, and the request for an APNs device token,
/// which arrives later through the app delegate.
@MainActor
protocol NotificationAuthorizing {
    func permission() async -> NotificationPermission
    /// Shows the iOS prompt; true when the member allows notifications.
    func requestPermission() async -> Bool
    func registerForRemoteNotifications()
}
