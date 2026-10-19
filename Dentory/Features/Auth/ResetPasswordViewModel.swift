import Foundation
import Observation

/// Reset password (MS-113, gap G4, not drawn): the email, prefilled from Sign in, and Send link. The answer
/// is the same sentence whether or not the address has an account, so the screen never tells who is a user.
@MainActor
@Observable
final class ResetPasswordViewModel {
    var email: String {
        didSet {
            guard email != oldValue else { return }
            emailError = nil
            sentTo = nil
        }
    }
    private(set) var emailError: String?
    /// The address the last link went to; the confirmation names it.
    private(set) var sentTo: String?
    /// A refusal that belongs to no field; the view shows it as a toast.
    private(set) var generalError: AppError?

    private let auth: AuthServicing
    private let submitGuard = SubmitGuard()

    init(email: String, auth: AuthServicing) {
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        self.auth = auth
    }

    var isSubmitting: Bool { submitGuard.isBusy }

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSend: Bool { !trimmedEmail.isEmpty && !isSubmitting }

    /// "If an account exists for sarah@smiledental.ca, a link is on its way."
    var confirmation: String? {
        sentTo.map { "If an account exists for \($0), a link is on its way." }
    }

    func send() async {
        guard canSend else { return }
        await submitGuard.run {
            generalError = nil
            let address = trimmedEmail
            do {
                try await auth.sendPasswordReset(email: address)
                sentTo = address
            } catch {
                switch AppError(error) {
                case .validation(let field, let message) where field == "email": emailError = message
                case let other: generalError = other
                }
            }
        }
    }

    func clearGeneralError() {
        generalError = nil
    }
}
