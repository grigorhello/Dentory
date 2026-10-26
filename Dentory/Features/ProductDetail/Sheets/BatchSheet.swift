import SwiftUI

/// Add expiry or Edit batch (Appendix C `batch`), both roles: the product's name, Expires (month), How many with
/// the unit and Lot side by side, a refusal as a notice, and Save last. `onSaved` receives the toast text.
struct BatchSheet: View {
    @State private var viewModel: BatchViewModel
    let onSaved: (BatchViewModel.Saved) -> Void

    init(viewModel: BatchViewModel, onSaved: @escaping (BatchViewModel.Saved) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        MSSheet(viewModel.title, caption: viewModel.productName, identifier: "batch") {
            MSMonthField(
                "Expires", selection: month, years: viewModel.years,
                opening: YearMonth(day: viewModel.openingMonth), identifier: "batch.expires"
            ) { viewModel.monthTitle(CalendarDay(yearMonth: $0)) }
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    MSTextField(
                        "How many", text: $viewModel.quantityText, identifier: "batch.quantity",
                        error: viewModel.quantityError, suffix: viewModel.unit, keyboard: .decimalPad
                    )
                    MSTextField(
                        "Lot (optional)", text: $viewModel.lot, identifier: "batch.lot", placeholder: "Free text"
                    )
                }
                // Under both fields, so the pair stays side by side whatever the sentence's length.
                if let hint = viewModel.quantityHint {
                    Text(hint)
                        .textStyle(.caption12)
                        .foregroundStyle(Color.ms.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("batch.quantityHint")
                }
            }
            if let error = viewModel.generalError {
                Notice(error.userMessage, tone: .danger)
                    .accessibilityIdentifier("batch.error")
            }
        } primary: {
            MSButton("Save", isFullWidth: true, isLoading: viewModel.isSubmitting, isDisabled: !viewModel.canSave) {
                Task { await viewModel.save() }
            }
            .accessibilityIdentifier("batch.save")
        }
        .onChange(of: viewModel.saved) { _, saved in
            guard let saved else { return }
            onSaved(saved)
        }
    }

    /// The month field works in `YearMonth`; the view model keeps the expiry as a first-of-month `CalendarDay`.
    private var month: Binding<YearMonth?> {
        Binding(
            get: { viewModel.expiryMonth.map(YearMonth.init(day:)) },
            set: { viewModel.expiryMonth = $0.map(CalendarDay.init(yearMonth:)) }
        )
    }
}

#Preview("Add expiry") {
    @Previewable @State var isPresented = true
    let dependencies = AppDependencies.preview()
    Color.ms.canvas
        .msSheet(isPresented: $isPresented) {
            BatchSheet(
                viewModel: BatchViewModel(
                    detail: .demoSeptocaine(), mode: .add, repository: dependencies.productDetailRepository,
                    formatters: dependencies.formatters(for: .demo)
                )
            ) { _ in isPresented = false }
        }
}
