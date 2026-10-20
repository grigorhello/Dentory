import SwiftUI

/// One batch on Expiring soon (f27): the name over "1 bottle · lot BA7 · Nov 2026", the days left in danger or
/// warning over the value, then View product and, for Admin, Mark disposed.
struct ExpiringCard: View {
    let batch: ExpiringBatch
    let line: String
    let daysText: String
    let daysTone: StatusTone
    let valueText: String
    let showsDispose: Bool
    let onView: () -> Void
    let onDispose: () -> Void

    private var identifier: String { "expiring.card[\(batch.id.uuidString.lowercased())]" }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(batch.name)
                            .textStyle(.bodyStrong16)
                            .foregroundStyle(Color.ms.ink)
                        Text(line)
                            .textStyle(.body14)
                            .foregroundStyle(Color.ms.textBody)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        Text(daysText)
                            .textStyle(.bodyStrong16)
                            .foregroundStyle(daysTone.foreground)
                        Text(valueText)
                            .textStyle(.body14)
                            .foregroundStyle(Color.ms.textSecondary)
                    }
                    .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(identifier)
                HStack(spacing: Spacing.md) {
                    MSButton("View product", variant: .tertiary, size: .small, action: onView)
                        .accessibilityIdentifier("\(identifier).view")
                    if showsDispose {
                        MSButton("Mark disposed", variant: .text, size: .small, action: onDispose)
                            .accessibilityIdentifier("\(identifier).dispose")
                    }
                }
            }
        }
    }
}

#Preview("Expiring card") {
    VStack(spacing: Spacing.lg) {
        ExpiringCard(
            batch: ExpiringBatch.demo[0], line: "1 bottle · lot BA7 · Nov 2026", daysText: "59 days",
            daysTone: .warning, valueText: "$82", showsDispose: true, onView: {}, onDispose: {}
        )
        ExpiringCard(
            batch: ExpiringBatch.demo[1], line: "34 cartridges · lot B441 · Dec 2026", daysText: "Expired",
            daysTone: .danger, valueText: "$104", showsDispose: false, onView: {}, onDispose: {}
        )
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
