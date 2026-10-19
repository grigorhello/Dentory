import Foundation
import Supabase

/// Reads `inventory_list` through `SupabaseClient.inventoryList(clinicID:)`, shared with Add item (MS-123).
struct SupabaseInventoryRepository: InventoryRepository {
    let client: SupabaseClient

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        try await client.inventoryList(clinicID: clinicID)
    }
}
