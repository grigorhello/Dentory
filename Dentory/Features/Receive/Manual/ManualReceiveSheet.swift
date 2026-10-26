import SwiftUI

/// The sheet over Receive manually: Choose product, or after its New, New product in the same sheet with the back
/// chevron to the list (Appendix C `newProduct`: "Back chevron when opened from pickProduct"). Create and select
/// chooses the new product on the form.
struct ManualReceiveSheet: View {
    @Environment(\.appDependencies) private var dependencies
    let viewModel: ManualReceiveViewModel
    let session: Session

    var body: some View {
        if viewModel.isCreatingProduct {
            ProductFormSheet(
                mode: .createAndSelect(name: viewModel.searchText), session: session, dependencies: dependencies,
                onBack: viewModel.backToPicker, onSaved: created
            )
        } else {
            PickProductSheet(viewModel: viewModel)
        }
    }

    /// Create and select: the new product is chosen on the form.
    private func created(_ outcome: ProductFormViewModel.Outcome) {
        guard case .created(let id) = outcome else { return }
        Task { await viewModel.productCreated(id) }
    }
}
