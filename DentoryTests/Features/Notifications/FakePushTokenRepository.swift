import Foundation
@testable import Dentory

/// Records each registration and removal; `failure` makes the next calls throw.
final class FakePushTokenRepository: PushTokenRepository, @unchecked Sendable {
    private(set) var registered: [String] = []
    private(set) var removed: [String] = []
    var failure: Error?

    func register(token: String) async throws {
        if let failure { throw failure }
        registered.append(token)
    }

    func remove(token: String) async throws {
        if let failure { throw failure }
        removed.append(token)
    }
}
