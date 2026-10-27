import SwiftUI

/// One countable supply of a procedure (f13, and Edit usage on f14): the name, a note only when needed ("0 will
/// remain", "Recorded 2"), −/+ around the quantity (blue when it differs from `reference`, never below 0) and the X,
/// which go under the name at the accessibility text sizes (MS-149).
struct ProcedureSupplyRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let productID: UUID
    let name: String
    let note: ProcedureLineNote?
    let reference: Int
    @Binding var quantity: Int
    let onRemove: () -> Void

    private var identifier: String { "procDetail.item[\(productID.uuidString.lowercased())]" }

    var body: some View {
        VStack(spacing: 0) {
            layout {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(name)
                        .textStyle(.body14)
                        .foregroundStyle(Color.ms.ink)
                    if let note {
                        Text(note.text)
                            .textStyle(.caption12)
                            .foregroundStyle(note.tone?.foreground ?? Color.ms.textSecondary)
                            .accessibilityIdentifier("\(identifier).warning")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: Spacing.sm) {
                    QuantityStepper(value: $quantity, reference: reference, name: name, identifier: identifier)
                    IconButton(.x, label: "Remove \(name)", variant: .quiet, size: .row, action: onRemove)
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
