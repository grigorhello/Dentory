import SwiftUI

/// The last ledger rows of the product (f20): the delta, what happened and who, the day. Show all opens
/// Activity's history filtered to the product (MS-134).
struct ProductHistoryCard: View {
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
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                            Text(row.deltaText)
                                .textStyle(.bodyStrong16)
                                .foregroundStyle(row.deltaTone.foreground)
                                .monospacedDigit()
                            Text(row.description)
                                .textStyle(.body16)
                                .foregroundStyle(Color.ms.textSecondary)
                                .lineLimit(2)
                            Spacer(minLength: Spacing.sm)
                            Text(row.dateText).textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
                        }
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
}
