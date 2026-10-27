import SwiftUI

/// Lot beside Expiry, both optional. The month wheels open full width under the pair, where they have room for the
/// month names, and the keyboard goes away first so it does not cover them; × clears a month chosen by mistake.
struct ManualReceiveBatchRow: View {
    @Bindable var viewModel: ManualReceiveViewModel
    var focus: FocusState<ManualReceiveForm.Field?>.Binding
    @State private var isExpiryOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            FieldRow {
                MSTextField("Lot", text: $viewModel.lot, identifier: "manual.lot", placeholder: "Optional")
                    .focused(focus, equals: .lot)
                    .frame(maxWidth: .infinity)
                MSMonthField(
                    "Expiry", selection: $viewModel.expiry, years: viewModel.years, opening: viewModel.openingMonth,
                    identifier: "manual.expiry", placeholder: "Optional", trailingIcon: .calendar,
                    clearLabel: "Clear expiry", wheelsOpen: $isExpiryOpen, title: viewModel.monthTitle
                )
                .frame(maxWidth: .infinity)
            }
            if isExpiryOpen {
                MSMonthWheels(
                    selection: $viewModel.expiry, years: viewModel.years, opening: viewModel.openingMonth,
                    identifier: "manual.expiry"
                )
            }
        }
        .onChange(of: isExpiryOpen) { _, isOpen in
            if isOpen { focus.wrappedValue = nil }
        }
    }
}
