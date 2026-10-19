import SwiftUI

/// One countable supply of a procedure (f13, and Edit usage on f14): the name, a note only when needed ("0 will
/// remain", "Recorded 2"), −/+ around the quantity (blue when it differs from `reference`, never below 0) and the X.
struct ProcedureSupplyRow: View {
    let productID: UUID
    let name: String
    let note: ProcedureLineNote?
    let reference: Int
    @Binding var quantity: Int
    let onRemove: () -> Void

    private var identifier: String { "procDetail.item[\(productID.uuidString.lowercased())]" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
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
                QuantityStepper(value: $quantity, reference: reference, identifier: identifier)
                IconButton(.x, label: "Remove \(name)", variant: .quiet, action: onRemove)
                    .accessibilityIdentifier("\(identifier).remove")
            }
            .padding(.vertical, Spacing.md)
            ListDivider()
        }
    }
}
