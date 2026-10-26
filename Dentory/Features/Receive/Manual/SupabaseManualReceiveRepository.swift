import Foundation
import Supabase

/// `receive_products` decodes straight into `ReceivableProduct`. The receipt goes through `WriteCoordinator`: online
/// now with an idempotency key, queued offline (MS-108).
struct SupabaseManualReceiveRepository: ManualReceiveRepository {
    let client: SupabaseClient
    let writes: WriteCoordinator

    func products(clinicID: UUID) async throws -> [ReceivableProduct] {
        do {
            return try await client
                .rpc("receive_products", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
                .execute()
                .value
        } catch {
            throw AppError(error)
        }
    }

    func receive(_ receipt: ManualReceipt) async throws -> WriteOutcome {
        try await writes.write("stock_receive", params: StockReceiveParams(receipt))
    }
}
