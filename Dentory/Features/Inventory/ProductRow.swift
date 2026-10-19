import SwiftUI

/// One product of the list: name, caption and the status badge (f16).
struct ProductRow: View {
    let product: ProductSummary
    let caption: String
    var showsDivider = true

    var body: some View {
        ListRow(product.name, caption: caption, badge: product.status.badgeKind, showsDivider: showsDivider)
    }
}

extension ProductStatus {
    /// The badge of PRD §7 for the status.
    var badgeKind: StatusBadgeKind {
        switch self {
        case .outOfStock: .outOfStock
        case .low: .low
        case .expiring: .expiring
        case .missingExpiry: .missingExpiry
        case .healthy: .healthy
        }
    }
}

#Preview("Rows") {
    ListCard {
        ProductRow(product: ProductSummary.demo[0], caption: "54 cartridges · Anesthetic")
        ProductRow(product: ProductSummary.demo[2], caption: "1 unopened · 1 open · Restorative")
        ProductRow(product: ProductSummary.demo[6], caption: "0 sheets · Endodontics", showsDivider: false)
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
