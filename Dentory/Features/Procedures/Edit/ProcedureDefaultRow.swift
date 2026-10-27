import SwiftUI

/// One default supply (f15): a countable product's name on one line, −/+ around its default (never under 1) and the
/// X; a multi-use product's name with "Multi-use · listed under Opened a new one?" and only the X.
struct ProcedureDefaultRow: View {
    let item: ProcedureEditViewModel.Item
    @Binding var quantity: Int
    let onRemove: () -> Void

    private var identifier: String { "procEdit.item[\(item.id.uuidString.lowercased())]" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(item.name)
                        .textStyle(.body14)
                        .foregroundStyle(Color.ms.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if item.tracking == .multiUse {
                        Text(ProcedureEditViewModel.multiUseCaption)
                            .textStyle(.caption12)
                            .foregroundStyle(Color.ms.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("\(identifier).caption")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if item.tracking == .countable {
                    QuantityStepper(value: $quantity, minimum: 1, name: item.name, identifier: identifier)
                }
                IconButton(.x, label: "Remove \(item.name)", variant: .quiet, size: .row, action: onRemove)
                    .accessibilityIdentifier("\(identifier).remove")
            }
            .padding(.vertical, Spacing.md)
            ListDivider()
        }
    }
}
