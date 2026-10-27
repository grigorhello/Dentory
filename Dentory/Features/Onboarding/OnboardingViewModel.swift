import Foundation
import Observation

/// Admin sign-up (f2, f3, f4): account, clinic, team. One submission at a time; inline errors under
/// the field the server named; the pending step survives a relaunch through `OnboardingProgressStoring`.
@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, Equatable { case account = 1, clinic, invite }

    struct InviteRow: Identifiable, Equatable {
        let id = UUID()
        var email = ""
        var role: MembershipRole = .staff
        var error: String?
    }

    private(set) var step: Step
    private(set) var isFinished = false

    // Step 1
    var fullName = "" { didSet { if fullName != oldValue { nameError = nil } } }
    var email = "" { didSet { if email != oldValue { emailError = nil } } }
    var password = "" { didSet { if password != oldValue { passwordError = nil } } }
    private(set) var nameError: String?
    private(set) var emailError: String?
    private(set) var passwordError: String?

    // Step 2
    var clinicName = "" { didSet { if clinicName != oldValue { clinicNameError = nil } } }
    var city = "" { didSet { if city != oldValue { cityError = nil } } }
    var country: Country?
    var logoData: Data?
    private(set) var clinicNameError: String?
    private(set) var cityError: String?
    let countries: [Country]
    private(set) var clinicID: UUID?

    // Step 3
    var invites: [InviteRow] = [InviteRow(), InviteRow()]

    /// A refusal that belongs to no field; the view shows it as a toast.
    private(set) var generalError: AppError?
    /// The toast after step 3 ("Invitations sent · They get a link by email.").
    private(set) var completionMessage: String?

    private let auth: AuthServicing
    private let repository: OnboardingRepository
    private let sessionStore: SessionStore
    private let progress: OnboardingProgressStoring
    private let analytics: Analytics
    private let timeZone: TimeZone
    private let submitGuard = SubmitGuard()

    init(
        auth: AuthServicing,
        repository: OnboardingRepository,
        sessionStore: SessionStore,
        progress: OnboardingProgressStoring,
        analytics: Analytics,
        locale: Locale = .current,
        timeZone: TimeZone = .current,
        startingAt step: Step = .account,
        account: Account? = nil,
        clinicID: UUID? = nil
    ) {
        self.auth = auth
        self.repository = repository
        self.sessionStore = sessionStore
        self.progress = progress
        self.analytics = analytics
        self.timeZone = timeZone
        self.step = step
        self.clinicID = clinicID
        countries = Country.all(locale: locale)
        country = Country.current(locale: locale, in: countries)
        if let account {
            fullName = account.fullName
            email = account.email
        }
    }

    var isSubmitting: Bool { submitGuard.isBusy }

    // MARK: - Step 1 · Account

    var canContinueAccount: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && Self.looksLikeEmail(email)
            && NewPassword.isLongEnough(password)
            && !isSubmitting
    }

    /// "At least 8 characters" under the password while it is too short, so a disabled Continue says why.
    var passwordHint: String? { NewPassword.hint(for: password) }

    func createAccount() async {
        guard canContinueAccount else { return }
        await submitGuard.run {
            generalError = nil
            do {
                let account = try await auth.signUp(
                    fullName: fullName.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                    password: password
                )
                sessionStore.didSignUp(account)
                step = .clinic
            } catch {
                handle(AppError(error))
            }
        }
    }

    // MARK: - Step 2 · Clinic

    var canCreateClinic: Bool {
        !clinicName.trimmingCharacters(in: .whitespaces).isEmpty
            && !city.trimmingCharacters(in: .whitespaces).isEmpty
            && country != nil
            && !isSubmitting
    }

    func createClinic() async {
        guard canCreateClinic, let country else { return }
        await submitGuard.run {
            generalError = nil
            do {
                let id = try await repository.createClinic(
                    name: clinicName.trimmingCharacters(in: .whitespaces),
                    city: city.trimmingCharacters(in: .whitespaces),
                    country: country.code,
                    timeZone: timeZone.identifier,
                    fullName: fullName.trimmingCharacters(in: .whitespaces)
                )
                clinicID = id
                progress.setPendingInviteClinicID(id)
                if let logoData {
                    // A failed logo never blocks the clinic; Clinic settings can retry it.
                    try? await repository.uploadLogo(clinicID: id, imageData: logoData)
                }
                await sessionStore.refresh()
                analytics.track(.clinicCreated)
                step = .invite
            } catch {
                handle(AppError(error))
            }
        }
    }

    // MARK: - Step 3 · Invite team

    func addInviteRow() {
        invites.append(InviteRow())
    }

    /// Rows with an address; blank rows are ignored, a malformed one blocks sending.
    var filledInvites: [TeamInvite] {
        invites.compactMap { row in
            let email = Self.normalized(row.email)
            return email.isEmpty ? nil : TeamInvite(email: email, role: row.role)
        }
    }

    var canSendInvites: Bool { !filledInvites.isEmpty && !isSubmitting }

    func sendInvites() async {
        guard let clinicID, canSendInvites else { return }
        var valid = true
        for index in invites.indices {
            let email = invites[index].email.trimmingCharacters(in: .whitespacesAndNewlines)
            invites[index].error = email.isEmpty || Self.looksLikeEmail(email) ? nil : "Enter a valid email"
            if invites[index].error != nil { valid = false }
        }
        guard valid else { return }
        await submitGuard.run {
            generalError = nil
            do {
                _ = try await repository.invite(clinicID: clinicID, invites: filledInvites)
                analytics.track(.onboardingFinished(invitations: filledInvites.count))
                finish(message: "Invitations sent\(Caption.separator)They get a link by email.")
            } catch {
                let appError = AppError(error)
                // A refusal of one address names it; it belongs under that row, not under step 1's email.
                if case .validation(let field, let message) = appError,
                   let index = invites.firstIndex(where: { Self.normalized($0.email) == field }) {
                    invites[index].error = message
                } else {
                    handle(appError)
                }
            }
        }
    }

    func skipInvites() {
        analytics.track(.onboardingFinished(invitations: 0))
        finish(message: nil)
    }

    func clearGeneralError() {
        generalError = nil
    }

    private func finish(message: String?) {
        progress.setPendingInviteClinicID(nil)
        completionMessage = message
        isFinished = true
    }

    private func handle(_ error: AppError) {
        switch error {
        case .validation(let field, let message) where field == "email": emailError = message
        case .validation(let field, let message) where field == "password": passwordError = message
        case .validation(let field, let message) where field == "name": nameError = message
        default: generalError = error
        }
    }

    /// Trimmed and lower-cased, the form every address is sent and compared in.
    nonisolated static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    nonisolated static func looksLikeEmail(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = trimmed.firstIndex(of: "@"), at != trimmed.startIndex else { return false }
        let domain = trimmed[trimmed.index(after: at)...]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".") && !trimmed.contains(" ")
    }
}
