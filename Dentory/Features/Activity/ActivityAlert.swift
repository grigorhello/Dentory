import Foundation

/// One open alert on Activity (PRD §6.8, §5 Alerts; f8), as `activity_alerts` reports it: one row per subject, with
/// what its sentence needs. Decoded with the client's decoder (`JSONDecoder.supabase`, snake_case keys) and cached
/// with its encoder.
nonisolated struct ActivityAlert: Codable, Equatable, Identifiable, Sendable {
    nonisolated enum Kind: String, Codable, Sendable {
        case outOfStock = "out_of_stock"
        case low
        case expiring
        case missingExpiry = "missing_expiry"
        /// A delivery read and waiting for review; listed for Admin only.
        case invoiceReady = "invoice_ready"
    }

    /// The alert's id; for an expiring batch, the alert of the latest threshold it crossed.
    let id: UUID
    let kind: Kind
    let openedAt: Date
    let thresholdDays: Int?
    let productID: UUID?
    let name: String?
    let unit: String?
    let tracking: TrackingMode?
    let minimum: Decimal?
    /// Stock now: a countable product's quantity, a multi-use product's unopened and open together.
    let quantity: Decimal?
    let unopened: Decimal?
    let batchID: UUID?
    let lot: String?
    let expiryMonth: CalendarDay?
    /// How many of the product's batches are expiring; the sentence names the lot when there are several.
    let expiringBatches: Int
    let invoiceID: UUID?
    let supplier: String?

    private enum CodingKeys: String, CodingKey {
        case id, kind, openedAt, thresholdDays, productID = "productId", name, unit, tracking, minimum, quantity
        case unopened, batchID = "batchId", lot, expiryMonth, expiringBatches, invoiceID = "invoiceId", supplier
    }
}
