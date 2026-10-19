import SwiftUI

/// The Adjust inventory sheet (f20 `product.adjust`): quantity with the unit suffix, the reason, a note
/// for Other, a refusal as a notice above the button, and Save adjustment last. `onSaved` receives the
/// result for the toast and its Undo.
struct AdjustInventorySheet: View {
    @State private var viewModel: AdjustInventoryViewModel
    let onSaved: (AdjustInventoryViewModel.Saved) -> Void

    init(viewModel: AdjustInventoryViewModel, onSaved: @escaping (AdjustInventoryViewModel.Saved) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        MSSheet("Adjust inventory", caption: viewModel.caption, identifier: "adjust") {
            MSTextField(
                viewModel.quantityLabel, text: $viewModel.quantityText, identifier: "adjust.quantity",
                error: viewModel.quantityError, suffix: viewModel.unit, keyboard: .decimalPad
            )
            MSPicker(
                "Reason", selection: $viewModel.reason, options: AdjustInventoryViewModel.reasons,
                identifier: "adjust.reason", placeholder: "Select a reason"
            ) { $0.label }
            if viewModel.needsNote {
                MSTextField(
                    "Note", text: $viewModel.note, identifier: "adjust.note",
                    placeholder: "What happened", hint: "Recorded in history with your name."
                )
            }
            if let error = viewModel.generalError {
                Notice(error.userMessage, tone: .danger)
                    .accessibilityIdentifier("adjust.error")
            }
        } primary: {
            MSButton(
                "Save adjustment", isFullWidth: true, isLoading: viewModel.isSubmitting,
                isDisabled: !viewModel.canSave
            ) {
                Task { await viewModel.save() }
            }
            .accessibilityIdentifier("adjust.save")
        }
        .animation(Motion.fastAnimation, value: viewModel.needsNote)
        .onChange(of: viewModel.saved) { _, saved in
            guard let saved else { return }
            onSaved(saved)
        }
    }
}

#Preview("Adjust inventory") {
    @Previewable @State var isPresented = true
    let dependencies = AppDependencies.preview()
    Color.ms.canvas
        .msSheet(isPresented: $isPresented) {
            AdjustInventorySheet(
                viewModel: AdjustInventoryViewModel(
                    detail: .demoSeptocaine(), repository: dependencies.productDetailRepository,
                    formatters: dependencies.formatters(for: .demo)
                )
            ) { _ in isPresented = false }
        }
}
