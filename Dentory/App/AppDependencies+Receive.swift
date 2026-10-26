import Foundation

/// Receive delivery's and Receive manually's view models (MS-126, MS-127), kept apart from the composition root's body.
extension AppDependencies {
    /// Receive delivery of the signed-in clinic, for its admin (MS-126). `canScan` says whether Take a photo opens the
    /// document scanner or, on a device without one, Photos.
    @MainActor
    func makeReceiveViewModel(session: Session, canScan: Bool) -> ReceiveViewModel {
        ReceiveViewModel(
            repository: receiveRepository, cache: cache, formatters: formatters(for: session),
            clinicID: session.clinicID, canScan: canScan
        )
    }

    /// Receive manually for the signed-in clinic's admin (MS-127), with `productID` already chosen when the route names
    /// one.
    @MainActor
    func makeManualReceiveViewModel(productID: UUID?, session: Session) -> ManualReceiveViewModel {
        ManualReceiveViewModel(
            repository: manualReceiveRepository, cache: cache, formatters: formatters(for: session),
            clinicID: session.clinicID, productID: productID, analytics: analytics
        )
    }
}
