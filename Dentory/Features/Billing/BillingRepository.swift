import Foundation

/// Billing for the admin (MS-140): the summary, and the Stripe pages that add or change the card.
protocol BillingRepository: Sendable {
    func summary(clinicID: UUID) async throws -> BillingSummary
    /// Stripe Checkout for a clinic without a subscription, or the Customer Portal for one with it. Nil when there is
    /// no page to open: the demo clinic changes its card at once.
    func paymentPage(clinicID: UUID, hasSubscription: Bool) async throws -> URL?
}
