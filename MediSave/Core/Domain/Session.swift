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

    var isAdmin: Bool { role == .admin }
}
