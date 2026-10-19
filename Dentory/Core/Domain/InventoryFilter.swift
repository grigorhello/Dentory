import Foundation

/// The chips of the Inventory list (f16). Home deep-links into one of them (MS-114); MS-115 draws the list.
nonisolated enum InventoryFilter: String, CaseIterable, Codable, Sendable {
    case all = "All"
    case low = "Low"
    case expiring = "Expiring"
    case missingExpiry = "Missing expiry"
    case healthy = "Healthy"

    /// Low includes Out of stock (f19); every other chip matches one status.
    func includes(_ status: ProductStatus) -> Bool {
        switch self {
        case .all: true
        case .low: status == .low || status == .outOfStock
        case .expiring: status == .expiring
        case .missingExpiry: status == .missingExpiry
        case .healthy: status == .healthy
        }
    }
}
