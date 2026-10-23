import Foundation

/// `clinics.subscription_status`: what `clinic_can_write` reads (MS-105), kept by the billing functions (MS-140).
nonisolated enum SubscriptionStatus: String, Codable, Sendable {
    case trialing
    case active
    case pastDue = "past_due"
    case canceled
    case readOnly = "read_only"

    /// Whether the clinic may change anything (MS-142), as `clinic_can_write` decides on the server: a subscription
    /// that is active or retrying a failed payment, or a trial that has not ended. The server refuses the rest.
    func allowsChanges(trialEndsAt: Date?, now: Date) -> Bool {
        switch self {
        case .active, .pastDue: true
        case .trialing: trialEndsAt.map { $0 > now } ?? true
        case .canceled, .readOnly: false
        }
    }
}
