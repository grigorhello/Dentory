import SwiftUI

/// "3 of 3 selected" with Clear, or Select all once nothing is ticked (f25, Admin).
struct ToBuySelectionBar: View {
    let viewModel: ToBuyViewModel

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(viewModel.selectionSummary)
                .textStyle(.body14)
                .foregroundStyle(Color.ms.textBody)
                .accessibilityIdentifier("order.selectionBar.summary")
            Spacer(minLength: Spacing.sm)
            MSButton(viewModel.selectionAction, variant: .text, size: .small, action: viewModel.toggleAll)
                .accessibilityIdentifier("order.selectionBar.toggle")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("order.selectionBar")
    }
}
