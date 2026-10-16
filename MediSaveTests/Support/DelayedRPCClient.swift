import Foundation
@testable import MediSave

/// Answers every call with a canned JSON result after a delay, counting the calls; for double-tap tests.
final class DelayedRPCClient: RPCCalling, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    let delay: Duration
    let response: Data

    init(delay: Duration = .milliseconds(100), response: Data = Data("\"00000000-0000-4000-8000-000000000009\"".utf8)) {
        self.delay = delay
        self.response = response
    }

    var callCount: Int { lock.withLock { count } }

    func call<Params: Encodable & Sendable, Result: Decodable & Sendable>(
        _ function: String,
        params: Params,
        idempotencyKey: UUID?
    ) async throws -> Result {
        lock.withLock { count += 1 }
        try await Task.sleep(for: delay)
        return try JSONDecoder.supabase.decode(Result.self, from: response)
    }
}
