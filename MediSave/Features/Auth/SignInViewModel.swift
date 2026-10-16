import Foundation
import Observation

/// Sign in (f1): two fields, inline errors from the server's refusal, one submission at a time.
@MainActor
@Observable
final class SignInViewModel {
    var email = "" {
        didSet { if email != oldValue { emailError = nil } }
    }
    var password = "" {
        didSet { if password != oldValue { passwordError = nil } }
    }
    var isPasswordShown = false
    private(set) var emailError: String?
    private(set) var passwordError: String?
    /// A refusal that belongs to no field; the view shows it as a toast.
    private(set) var generalError: AppError?

    private let sessionStore: SessionStore
    private let submitGuard = SubmitGuard()

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    var isSubmitting: Bool { submitGuard.isBusy }

    /// Disabled until both fields have text (PRD Appendix B `signin.submit`).
    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isSubmitting
    }

    func signIn() async {
        guard canSubmit else { return }
        await submitGuard.run {
            generalError = nil
            let email = self.email.trimmingCharacters(in: .whitespacesAndNewlines)
            if await sessionStore.signIn(email: email, password: password) { return }
            switch sessionStore.lastError {
            case .validation(let field, let message) where field == "email":
                emailError = message
            case .validation(let field, let message) where field == "password":
                passwordError = message
            case .forbidden:
                generalError = .forbidden
            case let error?:
                generalError = error
            case nil:
                generalError = .unknown("Sign in failed")
            }
        }
    }

    func clearGeneralError() {
        generalError = nil
    }

    /// Copy for a toast: a revoked membership has its own sentence (ticket MS-110).
    static func toastMessage(for error: AppError) -> String {
        error == .forbidden ? "You no longer have access to this clinic." : error.userMessage
    }
}
