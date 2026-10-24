import Foundation

/// Who is signed in and which clinic they act in. One clinic per user in V1.1.
nonisolated struct Session: Equatable, Sendable {
    let userID: UUID
    let email: String
    let fullName: String
    let clinicID: UUID
    let clinicName: String
    let role: MembershipRole
    /// ISO 4217, from the clinic.
    let currency: String
    /// IANA name, from the clinic.
    let timeZone: String
    /// The clinic's subscription and the trial's end (MS-142): whether the clinic may change anything.
    var subscriptionStatus: SubscriptionStatus = .trialing
    var trialEndsAt: Date?

    var isAdmin: Bool { role == .admin }

    /// False in read-only mode: the trial ended without a card, or the subscription ended (MS-142).
    func canWrite(at now: Date) -> Bool {
        subscriptionStatus.allowsChanges(trialEndsAt: trialEndsAt, now: now)
    }
}
