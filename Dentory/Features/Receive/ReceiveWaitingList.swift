import SwiftUI

/// "Waiting for delivery" (f22): the lines marked Ordered with "Patterson · ordered Oct 1" and the quantity, for
/// reference only, so no row reacts to a tap.
struct ReceiveWaitingList: View {
    let viewModel: ReceiveViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Eyebrow("Waiting for delivery")
                .accessibilityAddTraits(.isHeader)
            ListCard {
                ForEach(viewModel.waiting) { item in
                    ReceiveRow(
                        title: item.name, caption: viewModel.waitingLine(for: item),
                        value: viewModel.quantityText(for: item), showsDivider: item.id != viewModel.waiting.last?.id
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(item.name)
                    .accessibilityValue("\(viewModel.waitingLine(for: item)), \(viewModel.spokenQuantity(for: item))")
                    .accessibilityIdentifier("receive.waiting[\(item.id.uuidString.lowercased())]")
                }
            }
        }
    }
}
