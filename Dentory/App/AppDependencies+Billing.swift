import Foundation

/// Billing's view models (MS-140, MS-141), kept apart from the composition root's body.
extension AppDependencies {
    /// Billing of the signed-in clinic, for its admin (MS-140).
    @MainActor
    func makeBillingViewModel(session: Session) -> BillingViewModel {
        BillingViewModel(
            clinicID: session.clinicID, repository: billingRepository, cache: cache,
            formatters: formatters(for: session)
        )
    }

    /// Billing's invoices (f35, MS-141); `trialEndsAt` dates the empty state.
    @MainActor
    func makeInvoicesViewModel(session: Session, trialEndsAt: Date?) -> InvoicesViewModel {
        InvoicesViewModel(
            clinicID: session.clinicID, repository: billingRepository, cache: cache,
            formatters: formatters(for: session), trialEndsAt: trialEndsAt
        )
    }

    /// The billing emails sheet (MS-141); `onSaved` refreshes Billing's row.
    @MainActor
    func makeBillingEmailsViewModel(
        session: Session, onSaved: @escaping () async -> Void
    ) -> BillingEmailsViewModel {
        BillingEmailsViewModel(clinicID: session.clinicID, repository: billingRepository, onSaved: onSaved)
    }
}
