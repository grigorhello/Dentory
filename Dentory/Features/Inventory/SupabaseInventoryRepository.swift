import Foundation
import Supabase

/// Reads `inventory_list` through `SupabaseClient.inventoryList(clinicID:)`, shared with Add item (MS-123). The count
/// goes through `WriteCoordinator`: online now with an idempotency key, queued offline (MS-108).
struct SupabaseInventoryRepository: InventoryRepository {
    let client: SupabaseClient
    let writes: WriteCoordinator

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        try await client.inventoryList(clinicID: clinicID)
    }

    func applyCount(clinicID: UUID, counts: [CountedQuantity]) async throws -> WriteOutcome {
        try await writes.write(
            "stock_count_apply",
            params: StockCountParams(
                pClinicId: clinicID,
                pCounts: counts.map { StockCountParams.Line(productId: $0.productID, counted: $0.counted) }
            )
        )
    }
}
