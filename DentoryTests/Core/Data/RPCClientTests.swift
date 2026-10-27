import Foundation
import Supabase
import Testing
@testable import Dentory

struct RPCClientTests {
    private nonisolated struct AdjustParams: Encodable, Sendable {
        let pProductId: UUID
        let pActualQty: Decimal
        let pReason: String
    }

    private nonisolated struct Nothing: Decodable, Sendable {}

    @Test func attachesAGeneratedIdempotencyKey() async throws {
        let transport = FakeRPCTransport(response: .success(Data("\"00000000-0000-4000-8000-000000000001\"".utf8)))
        let key = UUID()
        let client = SupabaseRPCClient(transport: transport, makeKey: { key })
        let params = AdjustParams(pProductId: UUID(), pActualQty: 28, pReason: "Damaged")
        let action: UUID = try await client.call("stock_adjust", params: params)
        #expect(action.uuidString == "00000000-0000-4000-8000-000000000001")
        #expect(transport.sent.count == 1)
        #expect(transport.sent[0].function == "stock_adjust")
        #expect(transport.sent[0].params["p_idempotency_key"] == .string(key.uuidString.lowercased()))
        #expect(transport.sent[0].params["p_reason"] == .string("Damaged"))
    }

    @Test func keepsTheKeyItIsGiven() async throws {
        let transport = FakeRPCTransport(response: .success(Data("{}".utf8)))
        let client = SupabaseRPCClient(transport: transport)
        let key = UUID()
        let params = ["p_product_id": UUID().uuidString]
        let _: Nothing = try await client.call("bottle_open", params: params, idempotencyKey: key)
        #expect(transport.sent[0].params["p_idempotency_key"] == .string(key.uuidString.lowercased()))
    }

    @Test(arguments: [
        (PostgrestError(code: "42501", message: "only an admin can do this"), AppError.forbidden),
        (PostgrestError(code: "42501", message: "the clinic is read-only until a payment method is added"),
         AppError.readOnly),
        (PostgrestError(code: "22023", message: "a note is required to cancel"),
         AppError.validation(field: nil, message: "A note is required to cancel.")),
        (PostgrestError(hint: "name", code: "22023", message: "Another procedure is already called Filling."),
         AppError.validation(field: "name", message: "Another procedure is already called Filling.")),
        (PostgrestError(code: "PGRST116", message: "no rows"), AppError.notFound)
    ])
    func mapsPostgresErrors(_ error: PostgrestError, _ expected: AppError) async {
        let client = SupabaseRPCClient(transport: FakeRPCTransport(response: .failure(error)))
        await #expect(throws: expected) {
            let _: Nothing = try await client.call("stock_adjust", params: ["p": "x"])
        }
    }

    @Test func mapsNetworkErrors() async {
        let transport = FakeRPCTransport(response: .failure(URLError(.notConnectedToInternet)))
        let client = SupabaseRPCClient(transport: transport)
        await #expect(throws: AppError.network) {
            let _: Nothing = try await client.call("stock_adjust", params: ["p": "x"])
        }
    }

    /// MS-150: every call is timed once under its function's name and ends `ok` or with the error's kind, so Sentry
    /// can count the failures and chart the durations per function.
    @Test func timesEachCallUnderItsFunctionsName() async throws {
        let reporter = SpyErrorReporter()
        let transport = FakeRPCTransport()
        let client = SupabaseRPCClient(transport: transport, reporter: reporter)
        let _: Nothing = try await client.call("bottle_open", params: ["p_product_id": "x"])
        transport.response = .failure(PostgrestError(code: "22023", message: "Out of stock"))
        await #expect(throws: AppError.self) {
            let _: Nothing = try await client.call("stock_procedure_start", params: ["p": "x"])
        }
        transport.response = .failure(URLError(.notConnectedToInternet))
        await #expect(throws: AppError.network) {
            let _: Nothing = try await client.call("stock_count_apply", params: ["p": "x"])
        }
        transport.response = .success(Data("[1]".utf8))
        await #expect(throws: AppError.self) {
            let _: Nothing = try await client.call("stock_adjust", params: ["p": "x"])
        }
        #expect(reporter.started == ["bottle_open", "stock_procedure_start", "stock_count_apply", "stock_adjust"])
        #expect(reporter.finished == [
            SpyErrorReporter.Call(function: "bottle_open", outcome: "ok"),
            SpyErrorReporter.Call(function: "stock_procedure_start", outcome: "validation"),
            SpyErrorReporter.Call(function: "stock_count_apply", outcome: "network"),
            SpyErrorReporter.Call(function: "stock_adjust", outcome: "unknown")
        ])
    }

    @Test func userMessagesFollowThePRDCopy() {
        #expect(AppError.unknown("x").userMessage == "Couldn't save. Try again.")
        #expect(AppError.readOnly.userMessage
            == "Your clinic is in read-only mode. Add a card from the link in your billing email.")
        #expect(AppError.validation(field: nil, message: "Out of stock").userMessage == "Out of stock")
    }
}
