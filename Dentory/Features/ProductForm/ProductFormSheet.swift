import SwiftUI

/// New product / Edit product (PRD §6.4, Appendix C `newProduct`), Admin only: the fields, the live pack
/// conversion sentence and one full-width button that reads Create product or Save changes.
struct ProductFormSheet: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: ProductFormViewModel
    /// Called once the product is created or saved; the presenter closes the sheet and shows the toast.
    let onSaved: (ProductFormViewModel.Outcome) -> Void

    init(
        mode: ProductFormViewModel.Mode,
        session: Session,
        dependencies: AppDependencies,
        onSaved: @escaping (ProductFormViewModel.Outcome) -> Void
    ) {
        _viewModel = State(initialValue: dependencies.makeProductFormViewModel(mode: mode, session: session))
        self.onSaved = onSaved
    }

    var body: some View {
        MSSheet(viewModel.title, identifier: "newProduct") {
            ProductFormFields(viewModel: viewModel)
        } primary: {
            MSButton(
                viewModel.submitTitle, isFullWidth: true, isLoading: viewModel.isSubmitting,
                isDisabled: !viewModel.canSubmit
            ) {
                Task { await viewModel.save() }
            }
            .accessibilityIdentifier("newProduct.submit")
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.outcome) { _, outcome in
            guard let outcome else { return }
            onSaved(outcome)
        }
        .onChange(of: viewModel.generalError) { _, error in
            guard let error else { return }
            dependencies.toasts.show(error.userMessage)
            viewModel.clearGeneralError()
        }
    }
}

#Preview("New product") {
    Color.ms.canvas
        .msSheet(isPresented: .constant(true)) {
            ProductFormSheet(mode: .create, session: .demo, dependencies: .preview()) { _ in }
        }
        .environment(\.appDependencies, .preview())
}

#Preview("Edit product") {
    Color.ms.canvas
        .msSheet(isPresented: .constant(true)) {
            ProductFormSheet(mode: .edit(.demoSeptocaine()), session: .demo, dependencies: .preview()) { _ in }
        }
        .environment(\.appDependencies, .preview())
}
