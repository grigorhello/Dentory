import SwiftUI

/// The last ledger rows of the product (f20): the delta, what happened and who, the day. Show all opens
/// Activity's history filtered to the product (MS-134).
struct ProductHistoryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let rows: [ProductDetailViewModel.HistoryRow]
    let onShowAll: () -> Void

    var body: some View {
        Eyebrow("History")
            .accessibilityAddTraits(.isHeader)
        if rows.isEmpty {
            EmptyStateView("No history yet.")
        } else {
            ListCard {
                ForEach(rows) { row in
                    VStack(spacing: 0) {
                        line(row)
                            .padding(.vertical, Spacing.md)
                        if row.id != rows.last?.id {
                            ListDivider()
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("product.history[\(row.id.uuidString.lowercased())]")
                }
            }
            Button("Show all", action: onShowAll)
                .buttonStyle(.ms(.text, size: .medium))
                .accessibilityIdentifier("product.historyAll")
        }
    }

    /// The delta, what happened and who, and the day on one line, what happened taking the lines it needs (in two,
    /// "Physical count · Michael" lost its end at xxxLarge on an iPhone SE); one under the other at the accessibility
    /// text sizes, where between the delta and the day its words broke (MS-149).
    private func line(_ row: ProductDetailViewModel.HistoryRow) -> some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = AnyLayout.row(stacked: isStacked, alignment: .firstTextBaseline, stackedSpacing: Spacing.xxs)
        return layout {
            Text(row.deltaText)
                .textStyle(.bodyStrong16)
                .foregroundStyle(row.deltaTone.foreground)
                .monospacedDigit()
            Text(row.description)
                .textStyle(.body16)
                .foregroundStyle(Color.ms.textSecondary)
            if !isStacked {
                Spacer(minLength: Spacing.sm)
            }
            Text(row.dateText).textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
        }
    }
}
