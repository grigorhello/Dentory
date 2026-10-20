import SwiftUI

/// The top card of Inventory value (f10): the total in large figures, a line, then Expiring ≤ 90 d, Used, 30 d and
/// Received, 30 d in three equal columns.
struct InventoryValueTotalCard: View {
    let total: String
    let stats: [InventoryValueViewModel.Stat]

    var body: some View {
        CardView(padding: Spacing.page) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(total)
                    .figureStyle(.display48)
                    .foregroundStyle(Color.ms.ink)
                    .accessibilityLabel("Inventory value \(total)")
                    .accessibilityIdentifier("value.total.amount")
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ListDivider()
                    // 8 pt between columns, so "Received, 30 d" keeps one line on a 393 pt wide iPhone.
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        ForEach(stats) { stat in
                            StatColumn(stat: stat)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("value.total")
    }
}

/// One figure under the total: the short label over the amount.
private struct StatColumn: View {
    let stat: InventoryValueViewModel.Stat

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(stat.label)
                .textStyle(.body14)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(stat.value)
                .textStyle(.bodyStrong16)
                .foregroundStyle(stat.tone?.foreground ?? Color.ms.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.spokenLabel), \(stat.value)")
        .accessibilityIdentifier("value.stat.\(stat.id)")
    }
}

#Preview("Total card") {
    InventoryValueTotalCard(
        total: "$12,420",
        stats: [
            .init(
                id: "atRisk", label: "Expiring ≤ 90\u{00A0}d", spokenLabel: "Expiring", value: "$186", tone: .warning
            ),
            .init(id: "used", label: "Used, 30\u{00A0}d", spokenLabel: "Used", value: "$2,140", tone: nil),
            .init(id: "received", label: "Received, 30\u{00A0}d", spokenLabel: "Received", value: "$1,890", tone: nil)
        ]
    )
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
