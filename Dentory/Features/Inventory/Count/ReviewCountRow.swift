import SwiftUI

/// One row of Review corrections: the product, where it sits, "43 → 41" (up in success, down in danger)
/// and Undo, which puts the row back to its estimate.
struct ReviewCountRow: View {
    let product: ProductSummary
    let change: String
    let tone: StatusTone
    let showsDivider: Bool
    let onUndo: () -> Void

    private var identifier: String { "reviewCount.row[\(product.id.uuidString.lowercased())]" }

    var body: some View {
        ListRow(product.name, caption: product.location, showsDivider: showsDivider) {
            Text(change)
                .textStyle(.bodyStrong14)
                .monospacedDigit()
                .foregroundStyle(tone.foreground)
                .lineLimit(1)
                .fixedSize()
                .accessibilityIdentifier("\(identifier).change")
            MSButton("Undo", variant: .text, size: .small, action: onUndo)
                .accessibilityLabel("Undo \(product.name)")
                .accessibilityIdentifier("\(identifier).undo")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

#Preview("Review row") {
    ListCard {
        ReviewCountRow(product: ProductSummary.demo[0], change: "54 → 52", tone: .danger, showsDivider: true) {}
        ReviewCountRow(
            product: ProductSummary.demo[2], change: "1 → 2 unopened", tone: .success, showsDivider: false
        ) {}
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
