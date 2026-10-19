import Foundation

/// Keeps the count in progress in memory; for previews, UI tests and unit tests.
final class InMemoryCountDraftStore: CountDraftStoring, @unchecked Sendable {
    private var draft: StockCount?
    private let lock = NSLock()

    init(draft: StockCount? = nil) {
        self.draft = draft
    }

    func load() -> StockCount? { lock.withLock { draft } }
    func save(_ count: StockCount) { lock.withLock { draft = count } }
    func clear() { lock.withLock { draft = nil } }
}
