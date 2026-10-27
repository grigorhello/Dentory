import SwiftUI

/// The product's name, the screen's title in the 20 pt bold of every pushed title (f20), with its status badge beside
/// it, or under it when the two do not share a line, so a long name stays whole instead of wrapping around the badge.
struct ProductTitleRow: View {
    let name: String
    let status: ProductStatus

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                title.lineLimit(1).fixedSize()
                badge
            }
            VStack(alignment: .leading, spacing: Spacing.sm) {
                title.fixedSize(horizontal: false, vertical: true)
                badge
            }
        }
    }

    private var title: some View {
        Text(name)
            .textStyle(.title20)
            .foregroundStyle(Color.ms.ink)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("product.title")
    }

    private var badge: some View {
        StatusBadge(status.badgeKind, tone: status == .healthy ? .neutral : nil, showsDot: true)
            .accessibilityIdentifier("product.status")
    }
}
