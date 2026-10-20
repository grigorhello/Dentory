import Foundation

/// Device tokens without a server: remembered in memory, so the demo build signs devices in and out like the app.
final class DemoPushTokenRepository: PushTokenRepository, @unchecked Sendable {
    private var tokens: Set<String> = []
    private let lock = NSLock()

    var registered: Set<String> {
        lock.withLock { tokens }
    }

    func register(token: String) async throws {
        _ = lock.withLock { tokens.insert(token) }
    }

    func remove(token: String) async throws {
        _ = lock.withLock { tokens.remove(token) }
    }
}
