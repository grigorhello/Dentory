import Foundation

/// The parameters of `stock_count_apply`; the coordinator adds `p_idempotency_key`.
nonisolated struct StockCountParams: Encodable, Sendable {
    /// One element of `p_counts`, read by the function as `product_id` and `counted`.
    nonisolated struct Line: Encodable, Sendable {
        let productId: UUID
        let counted: Decimal
    }

    let pClinicId: UUID
    let pCounts: [Line]
}
