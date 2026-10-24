import Foundation

/// Screens Expiring soon pushes on the stack it was opened in.
enum ExpiringRoute: Hashable {
    /// Product detail for a batch's product (`expiring.card[batchId].view`).
    case product(UUID)
}
