import Foundation

/// The Inventory list's and the product sheets' view models (MS-115, MS-117, MS-121), kept apart from the composition
/// root's body.
extension AppDependencies {
    /// The Inventory list of the signed-in clinic (MS-115), which also counts stock (MS-121).
    @MainActor
    func makeInventoryListViewModel(session: Session) -> InventoryListViewModel {
        InventoryListViewModel(
            repository: inventoryRepository, cache: cache, draftStore: countDraftStore,
            formatters: formatters(for: session), clinicID: session.clinicID, userID: session.userID,
            analytics: analytics
        )
    }

    /// The New / Edit product sheet of the signed-in clinic (MS-117).
    @MainActor
    func makeProductFormViewModel(mode: ProductFormViewModel.Mode, session: Session) -> ProductFormViewModel {
        ProductFormViewModel(
            repository: productFormRepository, formatters: formatters(for: session), clinicID: session.clinicID,
            mode: mode, analytics: analytics
        )
    }
}
