import Foundation

/// Sign out, the password reset screens and the Join screen: the flows that end a session on this device or sign
/// another account in.
extension AppDependencies {
    /// Sign out's clean-up (MS-137), also run before a link signs another account in over the one on this device: an
    /// invitation (MS-112) or a password reset (MS-113), so nothing of the previous member carries over (F4).
    @MainActor
    func makeDeviceSignOut(sessionStore: SessionStore) -> DeviceSignOut {
        DeviceSignOut(
            sessionStore: sessionStore, cache: cache, writes: writes.queue, push: push,
            pendingLogo: pendingClinicLogo, countDraft: countDraftStore
        )
    }

    /// Reset password with the email typed on Sign in (MS-113).
    @MainActor
    func makeResetPasswordViewModel(email: String) -> ResetPasswordViewModel {
        ResetPasswordViewModel(email: email, auth: auth)
    }

    /// Set a new password for the token hash of a reset link (MS-113).
    @MainActor
    func makeSetPasswordViewModel(tokenHash: String, sessionStore: SessionStore) -> SetPasswordViewModel {
        SetPasswordViewModel(
            tokenHash: tokenHash, auth: auth, sessionStore: sessionStore,
            signingOut: makeDeviceSignOut(sessionStore: sessionStore)
        )
    }

    /// The Join screen's view model for the token of an invitation link (MS-112).
    @MainActor
    func makeAcceptInvitationViewModel(token: String, sessionStore: SessionStore) -> AcceptInvitationViewModel {
        AcceptInvitationViewModel(
            token: token, repository: invitationRepository, sessionStore: sessionStore,
            signingOut: makeDeviceSignOut(sessionStore: sessionStore), analytics: analytics
        )
    }
}
