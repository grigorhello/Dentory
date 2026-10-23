import Foundation

/// The product sheets' view models (MS-117), kept apart from the composition root's body.
extension AppDependencies {
    /// The New / Edit product sheet of the signed-in clinic (MS-117).
    @MainActor
    func makeProductFormViewModel(mode: ProductFormViewModel.Mode, session: Session) -> ProductFormViewModel {
        ProductFormViewModel(
            repository: productFormRepository, formatters: formatters(for: session), clinicID: session.clinicID,
            mode: mode, analytics: analytics
        )
    }
}
