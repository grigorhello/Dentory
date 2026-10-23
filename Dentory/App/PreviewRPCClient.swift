import Foundation

/// Answers every function with an empty object; feature previews swap in their own fakes.
struct PreviewRPCClient: RPCCalling {
    func call<Params: Encodable & Sendable, Result: Decodable & Sendable>(
        _ function: String,
        params: Params,
        idempotencyKey: UUID?
    ) async throws -> Result {
        if let empty = try? JSONDecoder.supabase.decode(Result.self, from: Data("{}".utf8)) {
            return empty
        }
        throw AppError.unknown("No preview data for \(function)")
    }
}
