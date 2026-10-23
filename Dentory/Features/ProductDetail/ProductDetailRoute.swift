import Foundation

/// Where Product detail leads on whichever stack it was pushed on: Show all opens the product's history (MS-134).
enum ProductDetailRoute: Hashable {
    case history(productID: UUID, name: String)
}
