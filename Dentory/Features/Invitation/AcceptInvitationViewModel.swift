import Foundation
import Observation

/// Accept invitation (f5): reads the invitation behind the link's token, takes a name and a password,
/// accepts, signs in and hands over to Home. One submission at a time; inline errors under the field the
/// server named; an unknown, used or old token shows the expired state with a way to Sign in.
@MainActor
@Observable
final class AcceptInvitationViewModel {
    enum State: Equatable {
        case loading
        case loaded(Invitation)
        case expired
        case failed(AppError)
    }

    private(set) var state: State = .loading
    var fullName = "" { didSet { if fullName != oldValue { nameError = nil } } }
    var password = "" { didSet { if password != oldValue { passwordError = nil } } }
    private(set) var nameError: String?
    private(set) var passwordError: String?
    /// A refusal that belongs to no field; the view shows it as a toast.
    private(set) var generalError: AppError?
    /// Set once the membership is active and the session is signed in: the root shows Home.
    private(set) var isFinished = false

    static let minimumPasswordLength = 8

    private let token: String
    private let repository: InvitationRepository
    private let sessionStore: SessionStore
    private let analytics: Analytics
    private let submitGuard = SubmitGuard()

    init(token: String, repository: InvitationRepository, sessionStore: SessionStore, analytics: Analytics) {
        self.token = token
        self.repository = repository
        self.sessionStore = sessionStore
        self.analytics = analytics
    }

    var isSubmitting: Bool { submitGuard.isBusy }

    var invitation: Invitation? {
        if case .loaded(let invitation) = state { return invitation }
        return nil
    }

    /// "Sarah Mitchell invited you as Staff. Set a password to finish."
    var caption: String? {
        invitation.map { "\($0.invitedByName) invited you as \($0.role.label). Set a password to finish." }
    }

    var canJoin: Bool {
        invitation != nil
            && !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= Self.minimumPasswordLength
            && !isSubmitting
    }

    func load() async {
        state = .loading
        do {
            guard let invitation = try await repository.invitation(token: token) else {
                state = .expired
                return
            }
            if fullName.isEmpty { fullName = invitation.fullName }
            state = .loaded(invitation)
        } catch {
            state = .failed(AppError(error))
        }
    }

    func join() async {
        guard canJoin, let invitation else { return }
        await submitGuard.run {
            generalError = nil
            let name = fullName.trimmingCharacters(in: .whitespaces)
            do {
                try await repository.accept(token: token, fullName: name, password: password)
            } catch AppError.notFound {
                state = .expired
                return
            } catch {
                handle(AppError(error))
                return
            }
            if await sessionStore.signIn(email: invitation.email, password: password) {
                analytics.track(.invitationAccepted)
                isFinished = true
            } else {
                generalError = sessionStore.lastError ?? .unknown("Sign in failed")
            }
        }
    }

    func clearGeneralError() {
        generalError = nil
    }

    private func handle(_ error: AppError) {
        switch error {
        case .validation(let field, let message) where field == "password": passwordError = message
        case .validation(let field, let message) where field == "full_name" || field == "name": nameError = message
        default: generalError = error
        }
    }
}
