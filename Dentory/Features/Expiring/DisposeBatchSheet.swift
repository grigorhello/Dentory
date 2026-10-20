import SwiftUI

/// Mark disposed (Appendix C `dispose`, Admin): "{name} · lot {lot}. Removed with reason Expired.", the quantity
/// disposed (the whole batch by default, never more), a refusal above the buttons, danger Mark disposed and Keep.
/// `onDisposed` receives the result for the toast and its Undo.
struct DisposeBatchSheet: View {
    @State private var viewModel: DisposeBatchViewModel
    let onKeep: () -> Void
    let onDisposed: (DisposeBatchViewModel.Disposed) -> Void

    init(
        viewModel: DisposeBatchViewModel, onKeep: @escaping () -> Void,
        onDisposed: @escaping (DisposeBatchViewModel.Disposed) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onKeep = onKeep
        self.onDisposed = onDisposed
    }

    var body: some View {
        MSSheet("Mark disposed", caption: viewModel.caption, identifier: "dispose") {
            MSTextField(
                "Quantity disposed", text: $viewModel.quantityText, identifier: "dispose.quantity",
                error: viewModel.quantityError, suffix: viewModel.batch.unit, keyboard: .decimalPad
            )
            if let error = viewModel.generalError {
                Notice(error.userMessage, tone: .danger)
                    .accessibilityIdentifier("dispose.error")
            }
        } primary: {
            VStack(spacing: Spacing.sm) {
                MSButton(
                    "Mark disposed", variant: .danger, isFullWidth: true, isLoading: viewModel.isSubmitting,
                    isDisabled: !viewModel.canDispose, action: dispose
                )
                .accessibilityIdentifier("dispose.confirm")
                MSButton("Keep", variant: .text, isFullWidth: true, action: onKeep)
                    .accessibilityIdentifier("dispose.keep")
            }
        }
        .onChange(of: viewModel.disposed) { _, disposed in
            guard let disposed else { return }
            onDisposed(disposed)
        }
    }

    private func dispose() {
        Task { await viewModel.dispose() }
    }
}

#Preview("Mark disposed") {
    @Previewable @State var isPresented = true
    let dependencies = AppDependencies.preview()
    Color.ms.canvas
        .msSheet(isPresented: $isPresented) {
            DisposeBatchSheet(
                viewModel: DisposeBatchViewModel(
                    batch: ExpiringBatch.demo[1], repository: dependencies.expiringRepository,
                    formatters: dependencies.formatters(for: .demo)
                ),
                onKeep: { isPresented = false },
                onDisposed: { _ in isPresented = false }
            )
        }
}
