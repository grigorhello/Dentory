import Foundation
import Supabase

/// Auth storage that forgets everything with the client that owns it: a reset link's recovery session never reaches
/// the Keychain, where the device's own session lives (MS-113, security review F4).
nonisolated final class InMemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) throws {
        lock.withLock { values[key] = value }
    }

    func retrieve(key: String) throws -> Data? {
        lock.withLock { values[key] }
    }

    func remove(key: String) throws {
        lock.withLock { _ = values.removeValue(forKey: key) }
    }
}
