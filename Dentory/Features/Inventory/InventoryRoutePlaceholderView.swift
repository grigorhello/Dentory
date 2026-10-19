import SwiftUI

/// A pushed screen that names the ticket bringing the real one.
struct InventoryRoutePlaceholderView: View {
    let route: InventoryRoute

    var body: some View {
        Text("\(title) arrives with its own ticket.")
            .textStyle(.body14)
            .foregroundStyle(Color.ms.textSecondary)
            .pushedScreen(title: title, identifier: identifier)
    }

    private var title: String {
        switch route {
        case .product: "Product detail"
        case .receive: "Receive delivery"
        }
    }

    private var identifier: String {
        switch route {
        case .product: "product"
        case .receive: "receive"
        }
    }
}
