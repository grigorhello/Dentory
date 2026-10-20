import Foundation

/// Reads what Inventory value shows (MS-135).
protocol InventoryValueRepository: Sendable {
    /// `inventory_value`: the total, the three figures under it, the value by category and the top five products.
    func value(clinicID: UUID) async throws -> InventoryValue
}
