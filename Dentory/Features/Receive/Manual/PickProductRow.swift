import SwiftUI

/// A product on Choose product: its name over its stock, and the check when it is the chosen one.
struct PickProductRow: View {
    let product: ReceivableProduct
    let caption: String
    let isChosen: Bool
    let onChoose: () -> Void

    var body: some View {
        Button(action: onChoose) {
            ListRow(product.name, caption: caption) {
                IconView(.check, size: 20)
                    .foregroundStyle(Color.ms.primary)
                    .opacity(isChosen ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
        .accessibilityIdentifier("pickProduct.row[\(product.id.uuidString.lowercased())]")
    }
}
