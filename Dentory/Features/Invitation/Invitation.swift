import Foundation

/// What the Join screen (f5) shows before the invitee has an account, read from `invitation_lookup`.
nonisolated struct Invitation: Equatable, Sendable {
    let clinicName: String
    let invitedByName: String
    let role: MembershipRole
    let email: String
    /// The name the admin typed, or empty when they gave none.
    let fullName: String
    let expiresAt: Date
}
