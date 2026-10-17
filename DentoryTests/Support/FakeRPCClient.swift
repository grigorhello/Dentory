import Foundation
@testable import Dentory

/// Records every call and answers from a queue of canned results (JSON) or errors.
final class FakeRPCClient: RPCCalling, @unchecked Sendable {
    struct Call: Equatable {
        let function: String
        let params: [String: String]
        let idempotencyKey: UUID?
    }

    private(set) var calls: [Call] = []
    var results: [Result<Data, Error>] = []

    init(results: [Result<Data, Error>] = []) {
        self.results = results
    }

    func call<Params: Encodable & Sendable, Result: Decodable & Sendable>(
        _ function: String,
        params: Params,
        idempotencyKey: UUID?
    ) async throws -> Result {
        let data = try JSONEncoder.supabase.encode(params)
        let object = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        calls.append(Call(function: function, params: object.mapValues { "\($0)" }, idempotencyKey: idempotencyKey))
        guard !results.isEmpty else { throw AppError.unknown("No canned result for \(function)") }
        switch results.removeFirst() {
        case .success(let data): return try JSONDecoder.supabase.decode(Result.self, from: data)
        case .failure(let error): throw error
        }
    }
}
