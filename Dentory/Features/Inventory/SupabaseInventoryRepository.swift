import Foundation
import Supabase

/// Rows decode with the client's decoder (`JSONDecoder.supabase`, snake_case keys). The count goes through
/// `WriteCoordinator`: online now with an idempotency key, queued offline (MS-108).
struct SupabaseInventoryRepository: InventoryRepository {
    let client: SupabaseClient
    let writes: WriteCoordinator

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        do {
            let rows: [InventoryRow] = try await client
                .rpc("inventory_list", params: ["p_clinic_id": clinicID.uuidString.lowercased()])
                .execute()
                .value
            return rows.map(ProductSummary.init(row:))
        } catch {
            throw AppError(error)
        }
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

/// A row of `inventory_list`.
nonisolated struct InventoryRow: Decodable, Sendable {
    let productId: UUID
    let name: String
    let categoryName: String?
    let unit: String
    let tracking: TrackingMode
    let location: String?
    let quantity: Decimal
    let unopened: Decimal
    let openCount: Int
    let minimum: Decimal
    let status: ProductStatus
}

extension ProductSummary {
    nonisolated init(row: InventoryRow) {
        self.init(
            id: row.productId,
            name: row.name,
            categoryName: row.categoryName,
            unit: row.unit,
            tracking: row.tracking,
            location: row.location,
            quantity: row.quantity,
            unopened: row.unopened,
            openCount: row.openCount,
            minimum: row.minimum,
            status: row.status
        )
    }
}
