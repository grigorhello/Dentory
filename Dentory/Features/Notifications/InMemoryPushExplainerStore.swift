import Foundation

/// The explainer's "offered" flag for previews, UI tests (`-pushExplainer` starts it unset) and unit tests.
final class InMemoryPushExplainerStore: PushExplainerStoring, @unchecked Sendable {
    private var offered: Bool
    private let lock = NSLock()

    init(hasOffered: Bool = false) {
        offered = hasOffered
    }

    var hasOffered: Bool {
        get { lock.withLock { offered } }
        set { lock.withLock { offered = newValue } }
    }
}
