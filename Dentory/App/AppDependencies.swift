import Foundation
import SwiftUI

/// The composition root: one instance of each shared service, built once in `DentoryApp` (live) or in
/// previews and tests (fakes). Views read it from the environment and hand their view model what it needs.
/// Feature repositories are added here by their own tickets.
struct AppDependencies: Sendable {
    let rpc: RPCCalling
    let auth: AuthServicing
    let clock: Clock
    let networkMonitor: NetworkMonitoring
    /// One toast at a time, shown once at the app level (MS-103).
    let toasts: ToastCenter
    /// Last answers of repository reads, shown while offline (MS-108).
    let cache: ResponseCaching
    /// The door for stock writes: online now, or queued and replayed (MS-108).
    let writes: WriteCoordinator
    let reporter: ErrorReporting
    let homeRepository: HomeRepository
    let inventoryRepository: InventoryRepository
    let productDetailRepository: ProductDetailRepository
    let proceduresRepository: ProceduresRepository
    let procedureStartRepository: ProcedureStartRepository
    let procedureEditRepository: ProcedureEditRepository
    let toBuyRepository: ToBuyRepository
    let activityRepository: ActivityRepository
    let onboardingRepository: OnboardingRepository
    let onboardingProgress: OnboardingProgressStoring
    let invitationRepository: InvitationRepository
    /// The device's locale; previews and UI tests use en_US so the frames' figures render as drawn.
    var locale: Locale = .current

    /// Formatters for the signed-in clinic.
    func formatters(for session: Session) -> ClinicFormatters {
        ClinicFormatters(
            currency: session.currency,
            timeZone: TimeZone(identifier: session.timeZone) ?? .current,
            locale: locale,
            clock: clock
        )
    }

    @MainActor
    static func live() -> AppDependencies {
        let client = SupabaseClientProvider.makeClient()
        let rpc = SupabaseRPCClient(transport: SupabaseRPCTransport(client: client))
        let clock = SystemClock()
        let networkMonitor = NetworkMonitor()
        let toasts = ToastCenter()
        let reporter = SentryErrorReporter()
        let writes = WriteCoordinator(
            rpc: rpc,
            queue: PendingWriteQueue(store: FilePendingWriteStore()),
            networkMonitor: networkMonitor,
            clock: clock,
            reporter: reporter,
            toasts: toasts
        )
        return AppDependencies(
            rpc: rpc,
            auth: SupabaseAuthService(client: client, passwordResetRedirect: PasswordResetLink.redirectURL()),
            clock: clock,
            networkMonitor: networkMonitor,
            toasts: toasts,
            cache: FileResponseCache(),
            writes: writes,
            reporter: reporter,
            homeRepository: SupabaseHomeRepository(client: client),
            inventoryRepository: SupabaseInventoryRepository(client: client),
            productDetailRepository: SupabaseProductDetailRepository(client: client, writes: writes),
            proceduresRepository: SupabaseProceduresRepository(client: client),
            procedureStartRepository: SupabaseProcedureStartRepository(client: client, writes: writes),
            procedureEditRepository: SupabaseProcedureEditRepository(client: client),
            toBuyRepository: SupabaseToBuyRepository(client: client),
            activityRepository: SupabaseActivityRepository(client: client),
            onboardingRepository: SupabaseOnboardingRepository(client: client),
            onboardingProgress: UserDefaultsOnboardingProgress(),
            invitationRepository: SupabaseInvitationRepository(client: client)
        )
    }

    /// No network: a demo clinic, a signed-in admin and a fixed moment, for previews and UI tests.
    @MainActor
    static func preview(
        signedIn: Bool = true, isConnected: Bool = true, role: MembershipRole = .admin, onboarding: String? = nil
    ) -> AppDependencies {
        let rpc = PreviewRPCClient()
        let clock = FixedClock(Session.demoNow)
        let networkMonitor = FixedNetworkMonitor(isConnected: isConnected)
        let toasts = ToastCenter()
        let reporter = NoopErrorReporter()
        let auth = PreviewAuthService(session: signedIn ? Session.demo(role: role) : nil)
        // `-onboarding clinic` resumes admin sign-up at step 2, `-onboarding invite` at step 3 (screenshots).
        if onboarding == "clinic" {
            auth.session = nil
            auth.account = Account(
                userID: Session.demo.userID, email: "owner@newclinic.ca", fullName: "Dr. Sarah Mitchell"
            )
        }
        let progress = InMemoryOnboardingProgress(pending: onboarding == "invite" ? Session.demo.clinicID : nil)
        let activity = DemoActivityRepository()
        return AppDependencies(
            rpc: rpc,
            auth: auth,
            clock: clock,
            networkMonitor: networkMonitor,
            toasts: toasts,
            cache: InMemoryResponseCache(),
            writes: WriteCoordinator(
                rpc: rpc,
                queue: PendingWriteQueue(store: InMemoryPendingWriteStore()),
                networkMonitor: networkMonitor,
                clock: clock,
                reporter: reporter,
                toasts: toasts
            ),
            reporter: reporter,
            homeRepository: DemoHomeRepository(activity: activity),
            inventoryRepository: DemoInventoryRepository(),
            productDetailRepository: DemoProductDetailRepository(byName: Session.demo(role: role).fullName),
            proceduresRepository: DemoProceduresRepository(),
            procedureStartRepository: DemoProcedureStartRepository(),
            procedureEditRepository: DemoProcedureEditRepository(),
            toBuyRepository: DemoToBuyRepository(),
            activityRepository: activity,
            onboardingRepository: DemoOnboardingRepository(auth: auth),
            onboardingProgress: progress,
            invitationRepository: DemoInvitationRepository(auth: auth),
            locale: Locale(identifier: "en_US")
        )
    }

    /// The Inventory list of the signed-in clinic (MS-115).
    @MainActor
    func makeInventoryListViewModel(session: Session) -> InventoryListViewModel {
        InventoryListViewModel(
            repository: inventoryRepository,
            cache: cache,
            formatters: formatters(for: session),
            clinicID: session.clinicID
        )
    }

    /// The Procedures tab of the signed-in clinic (MS-122).
    @MainActor
    func makeProceduresViewModel(session: Session) -> ProceduresViewModel {
        ProceduresViewModel(
            repository: proceduresRepository,
            cache: cache,
            formatters: formatters(for: session),
            clinicID: session.clinicID,
            isAdmin: session.isAdmin
        )
    }

    /// Adjust, then start for one template of the signed-in clinic (MS-123).
    @MainActor
    func makeProcedureStartViewModel(templateID: UUID, session: Session) -> ProcedureStartViewModel {
        ProcedureStartViewModel(
            repository: procedureStartRepository, formatters: formatters(for: session), clinicID: session.clinicID,
            templateID: templateID
        )
    }

    /// Edit procedure for one template of the signed-in clinic, or New procedure when `templateID` is nil (MS-125).
    @MainActor
    func makeProcedureEditViewModel(templateID: UUID?, session: Session) -> ProcedureEditViewModel {
        ProcedureEditViewModel(repository: procedureEditRepository, clinicID: session.clinicID, templateID: templateID)
    }

    /// To buy of the signed-in clinic (MS-128).
    @MainActor
    func makeToBuyViewModel(session: Session) -> ToBuyViewModel {
        ToBuyViewModel(
            repository: toBuyRepository, cache: cache, formatters: formatters(for: session),
            clinicID: session.clinicID, isAdmin: session.isAdmin
        )
    }

    /// Activity of the signed-in clinic, opened from Home's bell (MS-133).
    @MainActor
    func makeActivityViewModel(session: Session) -> ActivityViewModel {
        ActivityViewModel(
            repository: activityRepository, cache: cache, formatters: formatters(for: session),
            clinicID: session.clinicID
        )
    }

    /// Product detail for one product of the signed-in clinic (MS-116).
    @MainActor
    func makeProductDetailViewModel(productID: UUID, session: Session) -> ProductDetailViewModel {
        ProductDetailViewModel(
            repository: productDetailRepository,
            cache: cache,
            formatters: formatters(for: session),
            clinicID: session.clinicID,
            userID: session.userID,
            productID: productID
        )
    }

    /// The admin sign-up view model at the step the app state asks for.
    @MainActor
    func makeOnboardingViewModel(
        sessionStore: SessionStore,
        startingAt step: OnboardingViewModel.Step = .account,
        account: Account? = nil,
        clinicID: UUID? = nil
    ) -> OnboardingViewModel {
        OnboardingViewModel(
            auth: auth, repository: onboardingRepository, sessionStore: sessionStore, progress: onboardingProgress,
            locale: locale, startingAt: step, account: account, clinicID: clinicID
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
        SetPasswordViewModel(tokenHash: tokenHash, auth: auth, sessionStore: sessionStore)
    }

    /// The Join screen's view model for the token of an invitation link (MS-112).
    @MainActor
    func makeAcceptInvitationViewModel(token: String, sessionStore: SessionStore) -> AcceptInvitationViewModel {
        AcceptInvitationViewModel(token: token, repository: invitationRepository, sessionStore: sessionStore)
    }
}

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue = AppDependencies.preview()
}

extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

// MARK: - Preview doubles

extension Session {
    /// October 2, 2026, 9:41 in New York, the moment every frame shows (the frames label it a Thursday; it is a Friday).
    nonisolated static let demoNow = Date(timeIntervalSince1970: 1_790_933_260)

    nonisolated static let demo = demo(role: .admin)

    /// Sarah (Admin) or Michael (Staff) of the demo clinic (MS-109).
    nonisolated static func demo(role: MembershipRole) -> Session {
        Session(
            userID: UUID(uuidString: "00000000-0000-4000-8000-0000000000a1") ?? UUID(),
            email: role == .admin ? "sarah@smiledental.ca" : "michael@smiledental.ca",
            fullName: role == .admin ? "Sarah Mitchell" : "Michael Reyes",
            clinicID: UUID(uuidString: "00000000-0000-4000-8000-000000000001") ?? UUID(),
            clinicName: "Smile Dental",
            role: role,
            currency: "USD",
            timeZone: "America/New_York"
        )
    }
}

/// Answers every function with an empty object; feature previews swap in their own fakes.
struct PreviewRPCClient: RPCCalling {
    func call<Params: Encodable & Sendable, Result: Decodable & Sendable>(
        _ function: String,
        params: Params,
        idempotencyKey: UUID?
    ) async throws -> Result {
        if let empty = try? JSONDecoder.supabase.decode(Result.self, from: Data("{}".utf8)) {
            return empty
        }
        throw AppError.unknown("No preview data for \(function)")
    }
}

/// Signs in the demo clinic's people with the seed password (MS-109); anything else is refused the
/// way Supabase would. Sign-up creates an account in memory; `DemoOnboardingRepository` then sets the session.
final class PreviewAuthService: AuthServicing, @unchecked Sendable {
    var session: Session?
    var account: Account?
    /// Accounts the demo invitation flow created: address to the password set and the session it yields.
    private var registered: [String: (password: String, session: Session)] = [:]
    /// The demo admin, signed in by a good reset link until the new password is saved (MS-113).
    private var recovering: Session?
    static let demoPassword = "smiledental"
    static let demoEmails = ["sarah@smiledental.ca", "michael@smiledental.ca"]
    /// The one reset link that works without a server; any other token hash reads as expired.
    static let demoResetToken = "demo-reset"

    init(session: Session?) {
        self.session = session
    }

    func restore() async throws -> RestoredSession {
        if let session { return .signedIn(session) }
        if let account { return .needsClinic(account) }
        return .none
    }

    func register(email: String, password: String, session: Session) {
        registered[email.lowercased()] = (password, session)
    }

    func signIn(email: String, password: String) async throws -> Session {
        try await Task.sleep(for: .milliseconds(400))
        if let account = registered[email.lowercased()] {
            guard password == account.password else { throw AppError.wrongPassword }
            session = account.session
            return account.session
        }
        guard Self.demoEmails.contains(email.lowercased()) else { throw AppError.unknownEmail }
        guard password == Self.demoPassword else { throw AppError.wrongPassword }
        return .demo
    }

    func signUp(fullName: String, email: String, password: String) async throws -> Account {
        try await Task.sleep(for: .milliseconds(300))
        guard !Self.demoEmails.contains(email.lowercased()) else { throw AppError.emailTaken }
        let account = Account(userID: UUID(), email: email, fullName: fullName)
        self.account = account
        return account
    }

    func signOut() async throws {
        session = nil
        account = nil
    }

    /// Like Supabase: the same answer for a known and an unknown address; only a malformed one is refused.
    func sendPasswordReset(email: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
        guard email.contains("@") else { throw AppError.invalidEmail }
    }

    func verifyPasswordReset(tokenHash: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
        guard tokenHash == Self.demoResetToken else { throw AppError.notFound }
        recovering = .demo
    }

    func updatePassword(_ password: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
        guard password.count >= 8 else { throw AppError.shortPassword }
        guard let recovering else { throw AppError.unknown("No reset in progress") }
        session = recovering
        self.recovering = nil
    }
}
