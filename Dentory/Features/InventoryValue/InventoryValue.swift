import Foundation

/// What Inventory value shows (PRD §5, f10), as `inventory_value` reports it: every figure at the product's last
/// unit cost, a product without a cost counting as 0. Decoded with the client's decoder (`JSONDecoder.supabase`,
/// snake_case keys) and cached with its encoder.
nonisolated struct InventoryValue: Codable, Equatable, Sendable {
    /// Σ quantity × last unit cost of the active products: Home's Inventory value tile.
    let total: Decimal
    /// Batches expiring within 90 days or already expired: Home's "At risk, 90 days" tile.
    let atRisk90: Decimal
    /// What the procedures of the last 30 days took from stock, cancelled ones left out.
    let used30: Decimal
    /// What was received in the last 30 days.
    let received30: Decimal
    /// Products in stock without a cost yet; the total counts them as 0.
    let uncostedCount: Int
    /// Largest first; categories worth nothing are left out.
    let categories: [InventoryValueCategory]
    /// The five most valuable products, largest first.
    let topProducts: [InventoryValueProduct]
}
