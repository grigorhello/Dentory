import Foundation

/// Where Inventory value leads on the Home stack: a highest value product opens its Product detail.
enum InventoryValueRoute: Hashable {
    case product(UUID)
}
