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

    static let minimumPasswordLength = 8

    private let auth: AuthServicing
    private let repository: OnboardingRepository
    private let sessionStore: SessionStore
    private let progress: OnboardingProgressStoring
    private let timeZone: TimeZone
    private let submitGuard = SubmitGuard()

    init(
        auth: AuthServicing,
        repository: OnboardingRepository,
        sessionStore: SessionStore,
        progress: OnboardingProgressStoring,
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
            && password.count >= Self.minimumPasswordLength
            && !isSubmitting
    }

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
            let email = row.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
                finish(message: "Invitations sent · They get a link by email.")
            } catch {
                handle(AppError(error))
            }
        }
    }

    func skipInvites() {
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
        case .validation(nil, let message) where step == .clinic: clinicNameError = message
        default: generalError = error
        }
    }

    nonisolated static func looksLikeEmail(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = trimmed.firstIndex(of: "@"), at != trimmed.startIndex else { return false }
        let domain = trimmed[trimmed.index(after: at)...]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".") && !trimmed.contains(" ")
    }
}
