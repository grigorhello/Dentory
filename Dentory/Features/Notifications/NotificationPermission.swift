/// Whether iOS lets the app show notifications (MS-144): not asked yet, allowed (including provisional), or denied.
nonisolated enum NotificationPermission: Equatable, Sendable {
    case notDetermined
    case allowed
    case denied
}
