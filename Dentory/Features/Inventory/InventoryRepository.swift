import Foundation

/// Reads the products of a clinic for the Inventory list (MS-115).
protocol InventoryRepository: Sendable {
    /// `inventory_list`: every active product with its category, figures and status, in one call.
    func products(clinicID: UUID) async throws -> [ProductSummary]
}
