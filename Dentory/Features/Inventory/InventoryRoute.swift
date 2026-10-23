import Foundation

/// Screens the Inventory tab pushes on its own stack.
enum InventoryRoute: Hashable {
    /// Product detail (MS-116).
    case product(UUID)
    /// Receive delivery, from the empty clinic's state (MS-126).
    case receive
}
