import SwiftUI

/// One row of count mode (f18), laid out like the prototype's inventory row: the name, the sub-line under it, and
/// the stepper 12 pt to the right. A long name wraps beside the stepper rather than lose its end (MS-149).
struct InventoryCountRow: View {
    let product: ProductSummary
    let caption: String
    let isCorrected: Bool
    let showsDivider: Bool
    @Binding var value: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(product.name)
                        .textStyle(.body14)
                        .foregroundStyle(Color.ms.ink)
                    Text(caption)
                        .textStyle(.caption12)
                        .foregroundStyle(Color.ms.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                QuantityStepper(
                    value: $value,
                    isHighlighted: isCorrected,
                    name: product.name,
                    identifier: "inv.count.row[\(product.id.uuidString.lowercased())]"
                )
            }
            .padding(.vertical, Spacing.md + Spacing.xxs)
            .frame(minHeight: ControlHeight.hitTarget)
            if showsDivider {
                ListDivider()
            }
        }
    }
}

#Preview("Count row") {
    @Previewable @State var value = 52
    ListCard {
        InventoryCountRow(
            product: ProductSummary.demo[0], caption: "est. 54 cartridges · Operatory 1 · Drawer A",
            isCorrected: value != 54, showsDivider: false, value: $value
        )
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
