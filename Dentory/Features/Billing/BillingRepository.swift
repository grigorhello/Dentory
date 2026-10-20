import Foundation

/// Billing for the admin (MS-140): what Stripe and the trial say about the clinic. The app opens no Stripe page
/// (MS-100 D18); the links to add or change the card reach the clinic by email and from Grigor at onboarding.
protocol BillingRepository: Sendable {
    func summary(clinicID: UUID) async throws -> BillingSummary
}
