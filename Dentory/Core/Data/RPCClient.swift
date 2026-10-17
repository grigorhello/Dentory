import Foundation
import Supabase

/// Calls the Postgres functions of the stock engine (MS-106) and the rest. Every call carries an
/// idempotency key, so a retried request is a no-op on the server.
protocol RPCCalling: Sendable {
    func call<Params: Encodable & Sendable, Result: Decodable & Sendable>(
        _ function: String,
        params: Params,
        idempotencyKey: UUID?
    ) async throws -> Result
}

extension RPCCalling {
    /// Generates the idempotency key.
    func call<Params: Encodable & Sendable, Result: Decodable & Sendable>(
        _ function: String,
        params: Params
    ) async throws -> Result {
        try await call(function, params: params, idempotencyKey: nil)
    }
}

/// The wire: posts a function's JSON parameters and returns the JSON result. Swapped for a fake in tests.
protocol RPCTransport: Sendable {
    func execute(function: String, params: [String: AnyJSON]) async throws -> Data
}

/// Adds the key, sends, decodes and maps errors to `AppError`.
struct SupabaseRPCClient: RPCCalling {
    let transport: RPCTransport
    var makeKey: @Sendable () -> UUID = { UUID() }

    static let idempotencyParameter = "p_idempotency_key"

    func call<Params: Encodable & Sendable, Result: Decodable & Sendable>(
        _ function: String,
        params: Params,
        idempotencyKey: UUID?
    ) async throws -> Result {
        var object = try Self.jsonObject(from: params)
        object[Self.idempotencyParameter] = .string((idempotencyKey ?? makeKey()).uuidString.lowercased())
        let data: Data
        do {
            data = try await transport.execute(function: function, params: object)
        } catch {
            throw AppError(error)
        }
        do {
            return try JSONDecoder.supabase.decode(Result.self, from: data)
        } catch {
            throw AppError.unknown("Unreadable response from \(function)")
        }
    }

    private static func jsonObject(from params: some Encodable) throws -> [String: AnyJSON] {
        let data = try JSONEncoder.supabase.encode(params)
        guard case .object(let object) = try JSONDecoder.supabase.decode(AnyJSON.self, from: data) else {
            throw AppError.unknown("Function parameters must be an object")
        }
        return object
    }
}

/// The live transport on top of `SupabaseClient`.
struct SupabaseRPCTransport: RPCTransport {
    let client: SupabaseClient

    func execute(function: String, params: [String: AnyJSON]) async throws -> Data {
        try await client.rpc(function, params: params).execute().data
    }
}

extension AppError {
    /// Maps what the transport throws to the app's cases: `42501` is a permission or read-only refusal,
    /// `22023` a validation message, `PGRST116` not found, URL errors the network.
    init(_ error: Error) {
        if let appError = error as? AppError {
            self = appError
        } else if let postgrest = error as? PostgrestError {
            self = AppError(postgrest: postgrest)
        } else if error is URLError {
            self = .network
        } else {
            self = .unknown(error.localizedDescription)
        }
    }

    private init(postgrest: PostgrestError) {
        switch postgrest.code {
        case "42501":
            self = postgrest.message.localizedCaseInsensitiveContains("read-only") ? .readOnly : .forbidden
        case "22023", "23514", "23505":
            self = .validation(field: nil, message: postgrest.message)
        case "PGRST116", "42P01":
            self = .notFound
        default:
            self = .unknown(postgrest.message)
        }
    }
}

extension JSONEncoder {
    /// snake_case keys and ISO 8601 dates, as PostgREST expects.
    nonisolated static let supabase: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    /// snake_case keys and ISO 8601 instants. Postgres `date` columns decode as `CalendarDay`, not `Date`.
    nonisolated static let supabase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            if let date = ISO8601DateFormatter.fractional.date(from: value) {
                return date
            }
            if let date = ISO8601DateFormatter.plain.date(from: value) {
                return date
            }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unreadable date \(value)")
            )
        }
        return decoder
    }()
}

private extension ISO8601DateFormatter {
    nonisolated(unsafe) static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    nonisolated(unsafe) static let plain = ISO8601DateFormatter()
}
