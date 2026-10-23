import Foundation

/// Receive delivery's view model (MS-126), kept apart from the composition root's body.
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
}
