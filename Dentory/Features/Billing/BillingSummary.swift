import Foundation

/// Billing as `billing_summary` reports it to an admin (f34, PRD §6.9): the trial, the plan, the card, the invoices and
/// the billing emails. Decoded with the client's decoder (`JSONDecoder.supabase`, snake_case keys).
nonisolated struct BillingSummary: Codable, Equatable, Sendable {
    let trialEndsAt: Date
    let subscriptionStatus: SubscriptionStatus
    /// A Stripe subscription exists, its card added through Checkout.
    let hasSubscription: Bool
    /// The lifetime 50% promotion, set by Dentory and never in the app.
    let promoLifetime50: Bool
    let cardBrand: String?
    let cardLast4: String?
    /// The next payment of the subscription.
    let currentPeriodEnd: Date?
    let invoiceCount: Int
    /// The first billing email: the clinic's own list, or the first admin's address while it is empty.
    let billingEmail: String?
    let billingEmailCount: Int
}

/// `clinics.subscription_status`: what `clinic_can_write` reads (MS-105).
nonisolated enum SubscriptionStatus: String, Codable, Sendable {
    case trialing
    case active
    case pastDue = "past_due"
    case canceled
    case readOnly = "read_only"
}
