import Foundation

/// Reads an invitation by its token and accepts it (MS-112). Sending invitations is the admin's side:
/// `OnboardingRepository.invite` at sign-up, Team later.
protocol InvitationRepository: Sendable {
    /// `invitation_lookup`: nil when the token is unknown, already used or older than 7 days.
    func invitation(token: String) async throws -> Invitation?
    /// `accept_invitation`: creates the account (or sets the password of the account that already has the
    /// address) and makes the membership active. Throws `AppError.notFound` when the invitation expired
    /// meanwhile and `.validation(field: "password", …)` for a password the server refuses.
    func accept(token: String, fullName: String, password: String) async throws
}
