import Foundation

/// A signed-in user before they belong to a clinic (admin sign-up step 2, MS-111).
nonisolated struct Account: Equatable, Sendable {
    let userID: UUID
    let email: String
    let fullName: String
}

/// What `AuthServicing.restore()` finds on the device.
nonisolated enum RestoredSession: Equatable, Sendable {
    /// No stored session: show Sign in.
    case none
    case signedIn(Session)
    /// A stored user with no clinic yet: resume admin sign-up at the clinic step.
    case needsClinic(Account)
}
