import Foundation

/// Identifies one cached answer: the repository method and the clinic it was fetched for.
nonisolated struct CacheKey: Hashable, Sendable {
    let method: String
    let clinicID: UUID

    /// A file name safe for the Caches directory.
    var fileName: String {
        let method = self.method.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return "\(clinicID.uuidString.lowercased())-\(String(method)).json"
    }
}

/// Keeps the last answer of a repository method so a screen can show it while offline (PRD §7 errors).
/// Values are Codable JSON; nothing in them is sensitive beyond what the clinic already sees.
protocol ResponseCaching: Sendable {
    func store<Value: Encodable & Sendable>(_ value: Value, for key: CacheKey)
    func load<Value: Decodable & Sendable>(_ type: Value.Type, for key: CacheKey) -> Value?
    func removeAll()
}

/// JSON files in the Caches directory; iOS may purge them, which is fine.
struct FileResponseCache: ResponseCaching {
    let directory: URL

    init(directory: URL? = nil) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.directory = directory ?? caches.appending(path: "responses", directoryHint: .isDirectory)
    }

    func store<Value: Encodable & Sendable>(_ value: Value, for key: CacheKey) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder.supabase.encode(value)
            try data.write(to: url(for: key), options: .atomic)
        } catch {
            // A cache that cannot be written only means the next offline launch shows nothing.
        }
    }

    func load<Value: Decodable & Sendable>(_ type: Value.Type, for key: CacheKey) -> Value? {
        guard let data = try? Data(contentsOf: url(for: key)) else { return nil }
        return try? JSONDecoder.supabase.decode(type, from: data)
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func url(for key: CacheKey) -> URL {
        directory.appending(path: key.fileName)
    }
}

/// Holds answers in memory; for previews and tests.
final class InMemoryResponseCache: ResponseCaching, @unchecked Sendable {
    private var storage: [CacheKey: Data] = [:]
    private let lock = NSLock()

    func store<Value: Encodable & Sendable>(_ value: Value, for key: CacheKey) {
        guard let data = try? JSONEncoder.supabase.encode(value) else { return }
        lock.withLock { storage[key] = data }
    }

    func load<Value: Decodable & Sendable>(_ type: Value.Type, for key: CacheKey) -> Value? {
        guard let data = lock.withLock({ storage[key] }) else { return nil }
        return try? JSONDecoder.supabase.decode(type, from: data)
    }

    func removeAll() {
        lock.withLock { storage.removeAll() }
    }
}
