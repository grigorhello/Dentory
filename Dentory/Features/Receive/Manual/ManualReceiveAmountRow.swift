import SwiftUI

/// Quantity beside Cost per unit, both in the unit the product is received in, and the line saying what the quantity
/// does under the pair, so the two stay side by side whatever the line's length.
struct ManualReceiveAmountRow: View {
    @Bindable var viewModel: ManualReceiveViewModel
    var focus: FocusState<ManualReceiveForm.Field?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            FieldRow {
                MSTextField(
                    viewModel.quantityLabel, text: $viewModel.quantityText, identifier: "manual.qty", placeholder: "0",
                    error: viewModel.quantityError, keyboard: .decimalPad
                )
                .focused(focus, equals: .quantity)
                .frame(maxWidth: .infinity)
                MSTextField(
                    viewModel.costLabel, text: $viewModel.costText, identifier: "manual.cost", placeholder: "0.00",
                    error: viewModel.costError, prefix: viewModel.currencySymbol, keyboard: .decimalPad
                )
                .focused(focus, equals: .cost)
                .frame(maxWidth: .infinity)
            }
            if let effect = viewModel.effectLine {
                Text(effect)
                    .textStyle(.caption12)
                    .foregroundStyle(Color.ms.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("manual.effect")
            }
        }
    }
}
