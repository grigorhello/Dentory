import SwiftUI

/// The Expiry and Lot of a Matched or Created line (`invoice.line[n].expiry` and `.lot`), under a hairline, with the
/// micro line saying what no expiry means. The month wheels open full width under the pair, where they have room for
/// the month names, and the keyboard goes away first; × clears a month chosen by mistake. Both are saved a moment after
/// the last change, and the lot at once on Return or when the field is left.
struct InvoiceLineBatchRow: View {
    @Bindable var viewModel: InvoiceReviewViewModel
    let line: InvoiceLine
    let identifier: String
    @State private var isExpiryOpen = false
    @FocusState private var isLotFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ListDivider()
            HStack(alignment: .top, spacing: Spacing.sm) {
                MSMonthField(
                    InvoiceReviewViewModel.expiryLabel, selection: $viewModel[expiryOf: line.id],
                    years: viewModel.expiryYears(for: line), opening: viewModel.openingMonth,
                    identifier: "\(identifier).expiry", placeholder: InvoiceReviewViewModel.expiryPlaceholder,
                    trailingIcon: .calendar, clearLabel: "Clear expiry",
                    wheelsOpen: $isExpiryOpen, title: viewModel.monthTitle
                )
                .frame(maxWidth: .infinity)
                MSTextField(
                    InvoiceReviewViewModel.lotLabel, text: $viewModel[lotOf: line.id], identifier: "\(identifier).lot",
                    placeholder: InvoiceReviewViewModel.lotPlaceholder
                )
                .focused($isLotFocused)
                .onSubmit(saveLot)
                .frame(maxWidth: .infinity)
            }
            if isExpiryOpen {
                MSMonthWheels(
                    selection: $viewModel[expiryOf: line.id], years: viewModel.expiryYears(for: line),
                    opening: viewModel.openingMonth, identifier: "\(identifier).expiry"
                )
            }
            Text(InvoiceReviewViewModel.noExpiryHint)
                .textStyle(.caption12)
                .foregroundStyle(Color.ms.textSecondary)
                .padding(.top, -Spacing.xs)
                .accessibilityIdentifier("\(identifier).expiryHint")
        }
        .padding(.top, Spacing.xs)
        .onChange(of: isExpiryOpen) { _, isOpen in
            if isOpen { isLotFocused = false }
        }
        .onChange(of: isLotFocused) { _, isFocused in
            if !isFocused { saveLot() }
        }
    }

    /// Return, or leaving the field: the lot is saved now rather than a moment later.
    private func saveLot() {
        viewModel.saveBatchNow(of: line.id)
    }
}
