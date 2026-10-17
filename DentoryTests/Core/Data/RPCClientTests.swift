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
         AppError.validation(field: nil, message: "a note is required to cancel")),
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

    @Test func userMessagesFollowThePRDCopy() {
        #expect(AppError.unknown("x").userMessage == "Couldn't save. Try again.")
        #expect(AppError.readOnly.userMessage == "Add a payment method to keep making changes.")
        #expect(AppError.validation(field: nil, message: "Out of stock").userMessage == "Out of stock")
    }
}
