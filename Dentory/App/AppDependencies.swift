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
    let expiringRepository: ExpiringRepository
    let activityRepository: ActivityRepository
    let procedureEventRepository: ProcedureEventRepository
    let inventoryValueRepository: InventoryValueRepository
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
            expiringRepository: SupabaseExpiringRepository(client: client, writes: writes),
            activityRepository: SupabaseActivityRepository(client: client),
            procedureEventRepository: SupabaseProcedureEventRepository(client: client, writes: writes),
            inventoryValueRepository: SupabaseInventoryValueRepository(client: client),
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
        let expiring = DemoExpiringRepository()
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
            homeRepository: DemoHomeRepository(
                expiring: { expiring.currentBatches.map(\.value) },
                alertsUnseen: { activity.hasUnseenAlerts }
            ),
            inventoryRepository: DemoInventoryRepository(),
            productDetailRepository: DemoProductDetailRepository(byName: Session.demo(role: role).fullName),
            proceduresRepository: DemoProceduresRepository(),
            procedureStartRepository: DemoProcedureStartRepository(),
            procedureEditRepository: DemoProcedureEditRepository(),
            toBuyRepository: DemoToBuyRepository(),
            expiringRepository: expiring,
            activityRepository: activity,
            procedureEventRepository: DemoProcedureEventRepository(byName: Session.demo(role: role).fullName),
            inventoryValueRepository: DemoInventoryValueRepository(),
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

    /// Expiring soon of the signed-in clinic (MS-132) on `window` days, or the clinic's own window.
    @MainActor
    func makeExpiringViewModel(window: Int?, session: Session) -> ExpiringViewModel {
        ExpiringViewModel(
            repository: expiringRepository, cache: cache, formatters: formatters(for: session),
            clinicID: session.clinicID, isAdmin: session.isAdmin, window: window
        )
    }

    /// Activity's History of the signed-in clinic, or of one product from Product detail's Show all (MS-134).
    @MainActor
    func makeActivityHistoryViewModel(session: Session, productID: UUID?) -> ActivityHistoryViewModel {
        ActivityHistoryViewModel(
            repository: activityRepository, cache: cache, formatters: formatters(for: session),
            clinicID: session.clinicID, productID: productID
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

    /// A past procedure of the signed-in clinic, in editing mode straight away from Home's Edit usage (MS-124).
    @MainActor
    func makeProcedureEventViewModel(eventID: UUID, startsEditing: Bool, session: Session) -> ProcedureEventViewModel {
        ProcedureEventViewModel(
            repository: procedureEventRepository, formatters: formatters(for: session), clinicID: session.clinicID,
            eventID: eventID, startsEditing: startsEditing
        )
    }

    /// Inventory value of the signed-in clinic (MS-135).
    @MainActor
    func makeInventoryValueViewModel(session: Session) -> InventoryValueViewModel {
        InventoryValueViewModel(
            repository: inventoryValueRepository, cache: cache, formatters: formatters(for: session),
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
