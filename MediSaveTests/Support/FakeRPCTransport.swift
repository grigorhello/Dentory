import Foundation
import Supabase
@testable import MediSave

/// Captures what `SupabaseRPCClient` would send and answers with a canned body or error.
final class FakeRPCTransport: RPCTransport, @unchecked Sendable {
    private(set) var sent: [(function: String, params: [String: AnyJSON])] = []
    var response: Result<Data, Error>

    init(response: Result<Data, Error> = .success(Data("{}".utf8))) {
        self.response = response
    }

    func execute(function: String, params: [String: AnyJSON]) async throws -> Data {
        sent.append((function, params))
        return try response.get()
    }
}
