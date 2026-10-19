import SwiftUI

/// One countable supply (f13): the name, a warning line only when needed ("0 will remain", "Not available · 0 in
/// stock"), −/+ around the quantity (blue when it differs from the template's) and the X that removes it.
struct ProcedureSupplyRow: View {
    let supply: ProcedureStartViewModel.Supply
    let warning: ProcedureStartViewModel.Warning?
    @Binding var quantity: Int
    let onRemove: () -> Void

    private var identifier: String { "procDetail.item[\(supply.id.uuidString.lowercased())]" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(supply.item.name)
                        .textStyle(.body14)
                        .foregroundStyle(Color.ms.ink)
                    if let warning {
                        Text(warning.text)
                            .textStyle(.caption12)
                            .foregroundStyle(warning.tone.foreground)
                            .accessibilityIdentifier("\(identifier).warning")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                QuantityStepper(value: $quantity, reference: supply.defaultQuantity, identifier: identifier)
                IconButton(.x, label: "Remove \(supply.item.name)", variant: .quiet, action: onRemove)
                    .accessibilityIdentifier("\(identifier).remove")
            }
            .padding(.vertical, Spacing.md)
            ListDivider()
        }
    }
}
