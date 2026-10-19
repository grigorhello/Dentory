import Foundation

/// Screens the Inventory tab pushes on its own stack. Each arrives with its own ticket; until then the
/// destination is a placeholder pushed screen.
enum InventoryRoute: Hashable {
    /// Product detail (MS-116).
    case product(UUID)
    /// Receive delivery, from the empty clinic's state (MS-126).
    case receive
}
