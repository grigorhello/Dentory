import Foundation

/// Billing for the admin (MS-140, MS-141): what Stripe and the trial say about the clinic, its invoices, and the
/// addresses its invoices and receipts go to. The app opens no Stripe page (MS-100 D18); the links to add or change
/// the card reach the clinic by email and from Grigor at onboarding.
protocol BillingRepository: Sendable {
    func summary(clinicID: UUID) async throws -> BillingSummary

    /// Newest first; the $0 invoice that opens a trial is never kept.
    func invoices(clinicID: UUID) async throws -> [BillingInvoice]

    /// The billing emails, the primary first: the Stripe customer's address, not removable.
    func billingEmails(clinicID: UUID) async throws -> [String]

    /// Saves the addresses after the primary and answers the whole list as the server kept it.
    func saveBillingEmails(clinicID: UUID, extra: [String]) async throws -> [String]
}
