import Foundation

/// A row of `inventory_list` (MS-115). The Inventory list and Add item on Adjust, then start (MS-123) both read it
/// through `SupabaseClient.inventoryList(clinicID:)`, so it lives with the shared data types. Decoded with the
/// client's decoder (`JSONDecoder.supabase`, snake_case keys).
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
