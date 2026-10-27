import SwiftUI

/// "3 of 3 selected" with Clear, or Select all once nothing is ticked (f25, Admin). At the accessibility text sizes
/// the button goes under the line, which would otherwise break mid-word beside it ("selecte / d", MS-149).
struct ToBuySelectionBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let viewModel: ToBuyViewModel

    var body: some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        AnyLayout.row(stacked: isStacked) {
            Text(viewModel.selectionSummary)
                .textStyle(.body14)
                .foregroundStyle(Color.ms.textBody)
                .accessibilityIdentifier("order.selectionBar.summary")
            if !isStacked {
                Spacer(minLength: Spacing.sm)
            }
            MSButton(viewModel.selectionAction, variant: .text, size: .small, action: viewModel.toggleAll)
                .accessibilityIdentifier("order.selectionBar.toggle")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("order.selectionBar")
    }
}
