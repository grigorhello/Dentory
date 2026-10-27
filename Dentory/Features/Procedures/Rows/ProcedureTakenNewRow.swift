import SwiftUI

/// A bottle taken new, listed with the supplies (PRD §6.3): one item from stock, removed with its X or by tapping
/// Take new again.
struct ProcedureTakenNewRow: View {
    let productID: UUID
    let name: String
    let onRemove: () -> Void

    private var identifier: String { "procDetail.item[\(productID.uuidString.lowercased())]" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(name)
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
                    // Read as a stepper's number is: the product, then how many (MS-149).
                    .accessibilityLabel(name)
                    .accessibilityValue("1")
                    .accessibilityIdentifier("\(identifier).value")
                IconButton(.x, label: "Remove \(name)", variant: .quiet, size: .row, action: onRemove)
                    .accessibilityIdentifier("\(identifier).remove")
            }
            .padding(.vertical, Spacing.md)
            ListDivider()
        }
    }
}
