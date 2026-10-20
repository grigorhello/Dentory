import Foundation
import Supabase

/// The list decodes straight into `ExpiringList`; Mark disposed and its Undo go through `WriteCoordinator`:
/// online now with an idempotency key, queued offline (MS-108).
struct SupabaseExpiringRepository: ExpiringRepository {
    let client: SupabaseClient
    let writes: WriteCoordinator

    func batches(clinicID: UUID) async throws -> ExpiringList {
        do {
            return try await client
                .rpc("expiring_batches", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func dispose(batchID: UUID, quantity: Decimal) async throws -> WriteOutcome {
        try await writes.write("stock_dispose", params: StockDisposeParams(pBatchId: batchID, pQty: quantity))
    }

    func undoDisposal(actionID: UUID) async throws {
        _ = try await writes.write("undo_action", params: UndoActionParams(pActionId: actionID))
    }
}

/// The parameters of `stock_dispose`; the coordinator adds `p_idempotency_key`.
nonisolated struct StockDisposeParams: Encodable, Sendable {
    let pBatchId: UUID
    let pQty: Decimal
}
