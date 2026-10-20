import Foundation

/// Screens Home pushes on its own stack. Each arrives with its own ticket; until then the destination
/// is a placeholder pushed screen.
enum HomeRoute: Hashable {
    /// Activity, Alerts segment (MS-133).
    case alerts
    /// Account (MS-137).
    case account
    /// Expiring soon with a window in days (MS-132).
    case expiring(window: Int?)
    /// Inventory value by category (MS-135).
    case inventoryValue
    /// Receive delivery (MS-126).
    case receive
    /// A procedure event in editing mode (MS-124).
    case editUsage(eventID: UUID)
    /// Billing, from the read-only notice and sheet (MS-142).
    case billing
}
