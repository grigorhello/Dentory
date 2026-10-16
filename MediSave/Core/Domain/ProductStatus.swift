import Foundation

/// The one badge a product carries (PRD §5), mirroring `public.evaluate_product_status` so the app can show the
/// right status the moment a change lands, before the server's row arrives. Keep both in step: the same table of
/// cases tests each (`supabase/tests/database/07_product_status_test.sql`, `ProductStatusTests`).
nonisolated enum ProductStatus: String, Codable, Sendable, CaseIterable {
    case outOfStock = "out_of_stock"
    case low
    case expiring
    case missingExpiry = "missing_expiry"
    case healthy

    /// The PRD §7 status word.
    var title: String {
        switch self {
        case .outOfStock: "Out of stock"
        case .low: "Low"
        case .expiring: "Expiring"
        case .missingExpiry: "Missing expiry"
        case .healthy: "Healthy"
        }
    }

    /// What the rule looks at, as the `product_status` view reports it.
    struct Figures: Sendable, Equatable {
        var tracking: TrackingMode
        var quantity: Decimal
        var unopened: Decimal
        var minimum: Decimal
        var missingExpiryQuantity: Decimal
        /// Days to the last day of the soonest batch's month; nil without a dated batch.
        var daysToSoonestExpiry: Int?
        /// The clinic's largest expiry threshold (MS-100 D8).
        var largestThreshold: Int
    }

    /// Priority Out of stock › Low › Expiring › Missing expiry › Healthy. Low looks at unopened only for
    /// multi-use products (MS-100 G3); Expiring uses the clinic's largest threshold (D8).
    static func evaluate(_ figures: Figures) -> ProductStatus {
        if figures.quantity <= 0 { return .outOfStock }
        switch figures.tracking {
        case .multiUse where figures.unopened <= figures.minimum: return .low
        case .countable where figures.quantity <= figures.minimum: return .low
        default: break
        }
        if let days = figures.daysToSoonestExpiry, days <= figures.largestThreshold { return .expiring }
        if figures.missingExpiryQuantity > 0 { return .missingExpiry }
        return .healthy
    }
}
