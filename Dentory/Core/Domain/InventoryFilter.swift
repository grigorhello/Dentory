import Foundation

/// The chips of the Inventory list (f16). Home deep-links into one of them; MS-115 draws the list.
nonisolated enum InventoryFilter: String, CaseIterable, Sendable {
    case all = "All"
    case low = "Low"
    case expiring = "Expiring"
    case missingExpiry = "Missing expiry"
}
