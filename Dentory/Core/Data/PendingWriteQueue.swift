import Foundation
import Observation
import Supabase

/// A stock write made while offline: the function, its parameters and the idempotency key it will keep
/// when replayed, so a replay the server already saw is a no-op.
nonisolated struct PendingWrite: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let function: String
    let params: [String: AnyJSON]
    let createdAt: Date

    /// The key sent as `p_idempotency_key`; the same on every attempt.
    var idempotencyKey: UUID { id }
}

/// Where the queue lives between launches.
protocol PendingWriteStoring: Sendable {
    func load() -> [PendingWrite]
    func save(_ writes: [PendingWrite])
}

/// One JSON file in Application Support (backed up, never purged).
struct FilePendingWriteStore: PendingWriteStoring {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.fileURL = fileURL ?? support.appending(path: "pending-writes.json")
    }

    func load() -> [PendingWrite] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder.supabase.decode([PendingWrite].self, from: data)) ?? []
    }

    func save(_ writes: [PendingWrite]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder.supabase.encode(writes).write(to: fileURL, options: .atomic)
        } catch {
            // The writes stay in memory for this launch; the next save tries again.
        }
    }
}

/// Keeps the queue in memory; for previews and tests.
final class InMemoryPendingWriteStore: PendingWriteStoring, @unchecked Sendable {
    private var writes: [PendingWrite]
    private let lock = NSLock()

    init(writes: [PendingWrite] = []) {
        self.writes = writes
    }

    func load() -> [PendingWrite] { lock.withLock { writes } }
    func save(_ writes: [PendingWrite]) { lock.withLock { self.writes = writes } }
}

/// The writes waiting for a connection, oldest first, persisted on every change (PRD §7: offline writes
/// are queued and retried).
@MainActor
@Observable
final class PendingWriteQueue {
    private(set) var writes: [PendingWrite]
    private let store: PendingWriteStoring

    init(store: PendingWriteStoring) {
        self.store = store
        writes = store.load()
    }

    var isEmpty: Bool { writes.isEmpty }
    var count: Int { writes.count }

    func enqueue(function: String, params: [String: AnyJSON], key: UUID, at date: Date) -> PendingWrite {
        let write = PendingWrite(id: key, function: function, params: params, createdAt: date)
        writes.append(write)
        store.save(writes)
        return write
    }

    func remove(_ id: UUID) {
        writes.removeAll { $0.id == id }
        store.save(writes)
    }

    func removeAll() {
        writes.removeAll()
        store.save(writes)
    }
}
