import Foundation

/// The explainer's last offer for previews, UI tests (`-pushExplainer` starts it unset) and unit tests.
final class InMemoryPushExplainerStore: PushExplainerStoring, @unchecked Sendable {
    private var offered: Date?
    private let lock = NSLock()

    init(lastOffered: Date? = nil) {
        offered = lastOffered
    }

    var lastOffered: Date? {
        get { lock.withLock { offered } }
        set { lock.withLock { offered = newValue } }
    }
}
