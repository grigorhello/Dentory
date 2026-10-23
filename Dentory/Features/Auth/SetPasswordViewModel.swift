import Foundation
import Observation

/// Set a new password (MS-113), opened by the reset email's link: the link is checked once on open, then a
/// new password of at least 8 characters is saved and the session reloads, so Home is next. An expired or
/// used link shows its own state with a way to send a new one.
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
    /// Set once the password is saved and the session reloaded: the root drops the link and shows Home.
    private(set) var isFinished = false

    static let minimumPasswordLength = 8

    private let tokenHash: String
    private let auth: AuthServicing
    private let sessionStore: SessionStore
    private let submitGuard = SubmitGuard()
    /// The link's token works once; reopening the screen must not spend it again.
    private var didVerify = false

    init(tokenHash: String, auth: AuthServicing, sessionStore: SessionStore) {
        self.tokenHash = tokenHash
        self.auth = auth
        self.sessionStore = sessionStore
    }

    var isSubmitting: Bool { submitGuard.isBusy }

    var canSave: Bool {
        state == .ready && password.count >= Self.minimumPasswordLength && !isSubmitting
    }

    /// Checks the link the first time the screen appears.
    func verifyIfNeeded() async {
        guard !didVerify else { return }
        await verify()
    }

    /// Checks the link: a recovery session on success, the expired state for an old or used link.
    func verify() async {
        didVerify = true
        state = .verifying
        do {
            try await auth.verifyPasswordReset(tokenHash: tokenHash)
            state = .ready
        } catch AppError.notFound {
            state = .expired
        } catch {
            state = .failed(AppError(error))
        }
    }

    func save() async {
        guard canSave else { return }
        await submitGuard.run {
            generalError = nil
            do {
                try await auth.updatePassword(password)
            } catch {
                switch AppError(error) {
                case .validation(let field, let message) where field == "password": passwordError = message
                case let other: generalError = other
                }
                return
            }
            await sessionStore.refresh()
            isFinished = true
        }
    }

    func clearGeneralError() {
        generalError = nil
    }
}
