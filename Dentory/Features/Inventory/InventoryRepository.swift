import Foundation

/// Reads the products of a clinic for the Inventory list (MS-115) and applies a count (MS-121).
protocol InventoryRepository: Sendable {
    /// `inventory_list`: every active product with its category, figures and status, in one call.
    func products(clinicID: UUID) async throws -> [ProductSummary]

    /// `stock_count_apply`: one Count transaction per line, "Physical count". Goes through the write queue, so
    /// a count applied offline is replayed when the connection returns.
    func applyCount(clinicID: UUID, counts: [CountedQuantity]) async throws -> WriteOutcome
}
