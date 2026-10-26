import Foundation

/// The parameters of `stock_receive` for one manual receipt; the coordinator adds `p_idempotency_key`. The line is read
/// by the function as `product_id`, `qty`, `unit_cost`, `lot` and `expiry_month`; a missing cost, lot or expiry is left
/// out of it, which the function reads as null. `p_ref_id` keeps its default (null): a manual receipt has no invoice.
nonisolated struct StockReceiveParams: Encodable, Sendable {
    /// One element of `p_lines`.
    nonisolated struct Line: Encodable, Sendable {
        let productId: UUID
        let qty: Decimal
        let unitCost: Decimal?
        let lot: String?
        let expiryMonth: CalendarDay?
    }

    /// How the ledger names a receipt made here, as the demo clinic's own (`seed-demo.sql`).
    static let referenceLabel = "Receive manually"

    let pClinicId: UUID
    let pLines: [Line]
    let pRefType: String
    let pRefLabel: String

    init(_ receipt: ManualReceipt) {
        pClinicId = receipt.clinicID
        pLines = [Line(
            productId: receipt.productID, qty: receipt.quantity, unitCost: receipt.unitCost, lot: receipt.lot,
            expiryMonth: receipt.expiryMonth
        )]
        pRefType = "manual"
        pRefLabel = Self.referenceLabel
    }
}
