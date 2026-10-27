import SwiftUI

/// One default supply (f15): a countable product's name, −/+ around its default (never under 1) and the X; a
/// multi-use product's name with "Multi-use · listed under Opened a new one?" and only the X. A long name wraps rather
/// than lose its end, and the controls go under it at the accessibility text sizes (MS-149).
struct ProcedureDefaultRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: ProcedureEditViewModel.Item
    @Binding var quantity: Int
    let onRemove: () -> Void

    private var identifier: String { "procEdit.item[\(item.id.uuidString.lowercased())]" }

    var body: some View {
        VStack(spacing: 0) {
            layout {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(item.name)
                        .textStyle(.body14)
                        .foregroundStyle(Color.ms.ink)
                    if item.tracking == .multiUse {
                        Text(ProcedureEditViewModel.multiUseCaption)
                            .textStyle(.caption12)
                            .foregroundStyle(Color.ms.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("\(identifier).caption")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: Spacing.sm) {
                    if item.tracking == .countable {
                        QuantityStepper(value: $quantity, minimum: 1, name: item.name, identifier: identifier)
                    }
                    IconButton(.x, label: "Remove \(item.name)", variant: .quiet, size: .row, action: onRemove)
                        .accessibilityIdentifier("\(identifier).remove")
                }
            }
            .padding(.vertical, Spacing.md)
            ListDivider()
        }
    }

    private var layout: AnyLayout {
        .row(stacked: dynamicTypeSize.isAccessibilitySize, spacing: Spacing.sm)
    }
}
