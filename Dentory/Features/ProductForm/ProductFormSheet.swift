import SwiftUI

/// New product / Edit product (PRD §6.4, Appendix C `newProduct`), Admin only: the fields, the live pack
/// conversion sentence and one full-width button that reads Create product, Create and select (from Choose product,
/// with the back chevron to it) or Save changes.
struct ProductFormSheet: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: ProductFormViewModel
    /// Back to the sheet this one replaced (Choose product); nil draws no chevron.
    let onBack: (() -> Void)?
    /// Called once the product is created or saved; the presenter closes the sheet and shows the toast.
    let onSaved: (ProductFormViewModel.Outcome) -> Void

    init(
        mode: ProductFormViewModel.Mode,
        session: Session,
        dependencies: AppDependencies,
        onBack: (() -> Void)? = nil,
        onSaved: @escaping (ProductFormViewModel.Outcome) -> Void
    ) {
        _viewModel = State(initialValue: dependencies.makeProductFormViewModel(mode: mode, session: session))
        self.onBack = onBack
        self.onSaved = onSaved
    }

    var body: some View {
        MSSheet(viewModel.title, identifier: "newProduct", onBack: onBack) {
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

#Preview("New product from Choose product") {
    Color.ms.canvas
        .msSheet(isPresented: .constant(true)) {
            ProductFormSheet(
                mode: .createAndSelect(name: "Articaine"), session: .demo, dependencies: .preview(), onBack: {},
                onSaved: { _ in }
            )
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
