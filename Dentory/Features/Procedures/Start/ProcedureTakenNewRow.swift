import SwiftUI

/// A bottle taken new, listed with the supplies (PRD §6.3): one item from stock, removed with its X or by tapping
/// Take new again.
struct ProcedureTakenNewRow: View {
    let bottle: ProcedureStartViewModel.Bottle
    let onRemove: () -> Void

    private var identifier: String { "procDetail.item[\(bottle.id.uuidString.lowercased())]" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(bottle.item.name)
                        .textStyle(.body14)
                        .foregroundStyle(Color.ms.ink)
                    Text("Taken new")
                        .textStyle(.caption12)
                        .foregroundStyle(Color.ms.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // As wide as a stepper (three 44 pt parts), so the 1 sits under the other rows' values.
                Text("1")
                    .textStyle(.bodyStrong16)
                    .monospacedDigit()
                    .foregroundStyle(Color.ms.primary)
                    .frame(width: ControlHeight.hitTarget * 3)
                    .accessibilityIdentifier("\(identifier).value")
                IconButton(.x, label: "Remove \(bottle.item.name)", variant: .quiet, action: onRemove)
                    .accessibilityIdentifier("\(identifier).remove")
            }
            .padding(.vertical, Spacing.md)
            ListDivider()
        }
    }
}
