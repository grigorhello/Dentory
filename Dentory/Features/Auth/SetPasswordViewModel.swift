import Foundation
import Observation

/// Set a new password (MS-113), opened by the reset email's link: the link is checked once on open, on a client that
/// keeps nothing, so whoever is signed in here stays signed in (security review F4). The ready state names the link's
/// account; a new password of at least 8 characters is saved, and only then does that account sign in here, after
/// Sign out's clean-up when another account held the device. An expired or used link shows its own state with a way
/// to send a new one; every state has a way out to Sign in, or back to the account still signed in.
@MainActor
@Observable
final class SetPasswordViewModel {
    enum State: Equatable {
        case verifying
        case ready
        case expired
        case failed(AppError)
    }

    private(set) var state: State = .verifying
    var password = "" { didSet { if password != oldValue { passwordError = nil } } }
    var isPasswordShown = false
    private(set) var passwordError: String?
    /// A refusal that belongs to no field; the view shows it as a toast.
    private(set) var generalError: AppError?
    /// Set once the password is saved and the link's account signed in: the root drops the link and shows Home (or
    /// Sign in, when the recovery session ran out before the sign-in).
    private(set) var isFinished = false

    private let tokenHash: String
    private let auth: AuthServicing
    private let sessionStore: SessionStore
    private let signingOut: SigningOut
    private let submitGuard = SubmitGuard()
    /// The link's token works once; reopening the screen must not spend it again.
    private var didVerify = false
    /// The link's account and recovery session, once the link checked out.
    private var reset: PasswordReset?
    /// Set once the server took the new password: a retry after a failed sign-in only signs in, since saving the same
    /// password again would be refused as the current one.
    private var isPasswordSaved = false

    init(tokenHash: String, auth: AuthServicing, sessionStore: SessionStore, signingOut: SigningOut) {
        self.tokenHash = tokenHash
        self.auth = auth
        self.sessionStore = sessionStore
        self.signingOut = signingOut
    }

    var isSubmitting: Bool { submitGuard.isBusy }

    var canSave: Bool {
        state == .ready && NewPassword.isLongEnough(password) && !isSubmitting
    }

    /// "Choose a password for sarah@smiledental.ca": the account the link belongs to, which may not be the one signed
    /// in here.
    var caption: String {
        guard let email = reset?.email, !email.isEmpty else { return "Choose a password for your Dentory account." }
        return "Choose a password for \(email)"
    }

    /// The way out leads to Sign in on a signed-out device; otherwise it is Cancel, back to the account still signed in
    /// here.
    var leavesToSignIn: Bool { sessionStore.accountEmail == nil }

    /// "At least 8 characters" under the password while it is too short, so a disabled Save password says why.
    var passwordHint: String? { NewPassword.hint(for: password) }

    /// Checks the link the first time the screen appears.
    func verifyIfNeeded() async {
        guard !didVerify else { return }
        await verify()
    }

    /// Checks the link: the link's account on success, the expired state for an old or used link. The device's
    /// session is not touched.
    func verify() async {
        didVerify = true
        state = .verifying
        do {
            reset = try await auth.verifyPasswordReset(tokenHash: tokenHash)
            state = .ready
        } catch AppError.notFound {
            state = .expired
        } catch {
            state = .failed(AppError(error))
        }
    }

    func save() async {
        guard canSave, let reset else { return }
        await submitGuard.run {
            generalError = nil
            if !isPasswordSaved {
                guard let saved = await savePassword(for: reset) else { return }
                self.reset = saved
                isPasswordSaved = true
            }
            await signInLinkAccount()
        }
    }

    func clearGeneralError() {
        generalError = nil
    }

    /// The new password on the link's own session; nil when it was refused.
    private func savePassword(for reset: PasswordReset) async -> PasswordReset? {
        do {
            return try await auth.updatePassword(password, for: reset)
        } catch {
            switch AppError(error) {
            case .validation(let field, let message) where field == "password": passwordError = message
            case .notFound: state = .expired
            case let other: generalError = other
            }
            return nil
        }
    }

    /// The link's account signs in here, after Sign out's clean-up when the device held another account, while that
    /// account's session still lets the server drop this device's push token for it.
    private func signInLinkAccount() async {
        guard let reset else { return }
        if sessionStore.holdsAnotherAccount(than: reset.email) {
            await signingOut.signOut()
        }
        do {
            try await auth.signIn(with: reset)
        } catch AppError.notFound {
            // The recovery session ran out after the password was saved: the new password signs in from Sign in.
        } catch {
            generalError = AppError(error)
            return
        }
        await sessionStore.refresh()
        isFinished = true
    }
}
