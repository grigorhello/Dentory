import Foundation

/// A reset link that checked out (MS-113): the account it belongs to and the recovery session the link opened, held
/// in memory only. The device's own session stays as it is until the new password is saved; only then does the
/// link's account sign in here (security review F4).
nonisolated struct PasswordReset: Equatable, Sendable {
    let userID: UUID
    let email: String
    let accessToken: String
    let refreshToken: String
}
