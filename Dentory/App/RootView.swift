import SwiftUI

/// Signed out shows Sign in (MS-110); signed in shows the four tabs, each with its own
/// `NavigationStack` and path from `AppRouter`.
struct RootView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.scenePhase) private var scenePhase
    let sessionStore: SessionStore
    /// `-tab inventory` and `-inventoryFilter Low` open the app there (screenshots, UI tests).
    @State private var router = AppRouter(
        selectedTab: AppTab(rawValue: UserDefaults.standard.string(forKey: "tab") ?? "") ?? .home,
        inventoryFilter: UserDefaults.standard.string(forKey: "inventoryFilter")
            .flatMap(InventoryFilter.init(rawValue:))
    )
    /// Set while step 3 of admin sign-up is still due for the signed-in clinic.
    @State private var pendingInviteClinicID: UUID?
    @State private var didReadProgress = false
    @State private var foregroundReturn = ForegroundReturn()
    /// Admin sign-up steps and Reset password, pushed on Sign in. `-onboarding account` (screenshots) starts
    /// with step 1 already pushed.
    @State private var signInPath: NavigationPath
    /// The token of the invitation link that opened the app: the Join screen (f5) shows whatever the
    /// session is, and the new session replaces the old one when the invitee joins (MS-112).
    @State private var invitationToken: String?
    /// The token hash of the password reset link that opened the app: Set a new password shows whatever
    /// the session is, and the account of the link is signed in once the password is saved (MS-113).
    @State private var resetTokenHash: String?

    init(
        sessionStore: SessionStore,
        startsOnSignUp: Bool = false,
        invitationToken: String? = nil,
        resetTokenHash: String? = nil
    ) {
        self.sessionStore = sessionStore
        _signInPath = State(
            initialValue: startsOnSignUp ? NavigationPath([OnboardingViewModel.Step.account]) : NavigationPath()
        )
        _invitationToken = State(initialValue: invitationToken)
        _resetTokenHash = State(initialValue: resetTokenHash)
    }

    var body: some View {
        Group {
            if let invitationToken {
                NavigationStack {
                    AcceptInvitationView(
                        viewModel: dependencies.makeAcceptInvitationViewModel(
                            token: invitationToken, sessionStore: sessionStore
                        ),
                        onFinished: { self.invitationToken = nil },
                        onSignIn: { self.invitationToken = nil }
                    )
                    .id(invitationToken)
                }
            } else if let resetTokenHash {
                NavigationStack {
                    SetPasswordView(
                        viewModel: dependencies.makeSetPasswordViewModel(
                            tokenHash: resetTokenHash, sessionStore: sessionStore
                        ),
                        onFinished: {
                            dependencies.toasts.show("Password updated")
                            self.resetTokenHash = nil
                        },
                        onSignIn: { self.resetTokenHash = nil }
                    )
                    .navigationDestination(for: PasswordResetRoute.self) { resetPassword($0) }
                }
                // A newer link starts over, even when Reset password is pushed over the expired one.
                .id(resetTokenHash)
            } else {
                sessionContent
            }
        }
        .onOpenURL { url in
            // A link takes over the root; Sign in starts clean behind it, so leaving the link shows Sign in
            // itself, not a screen pushed before the link was opened (Reset password, sign-up).
            if let token = InvitationLink.token(from: url) {
                signInPath = NavigationPath()
                resetTokenHash = nil
                invitationToken = token
            } else if let tokenHash = PasswordResetLink.tokenHash(from: url) {
                signInPath = NavigationPath()
                invitationToken = nil
                resetTokenHash = tokenHash
            } else if let link = NotificationLink(url: url) {
                // A notification's link opens on the tabs, after sign-in when the app is signed out.
                dependencies.push.open(link)
            }
        }
        .onAppear {
            guard !didReadProgress else { return }
            didReadProgress = true
            pendingInviteClinicID = dependencies.onboardingProgress.pendingInviteClinicID()
        }
        .onChange(of: scenePhase) { _, phase in
            // Back from the background: a role changed or a removal elsewhere takes effect here (MS-138).
            guard foregroundReturn.phaseChanged(to: phase) else { return }
            Task { await sessionStore.revalidate() }
        }
        .onChange(of: sessionStore.state) { _, state in
            switch state {
            case .signedIn:
                // Step 2 just finished in this launch: step 3 shows before the tabs.
                pendingInviteClinicID = dependencies.onboardingProgress.pendingInviteClinicID()
                // Sign in shows clean after a later Sign out, without a sign-up step left pushed (MS-137).
                signInPath = NavigationPath()
            case .needsClinic:
                signInPath = NavigationPath()
            case .signedOut:
                // Whoever signs in next starts on Home, with nothing pushed or filtered (MS-137).
                router.reset()
            case .restoring:
                break
            }
        }
    }

    /// Signed out, admin sign-up in progress, or the tabs.
    @ViewBuilder private var sessionContent: some View {
        switch sessionStore.state {
        case .restoring:
            ProgressView()
                .tint(Color.ms.primary)
                .accessibilityIdentifier("root.restoring")
        case .signedOut:
            NavigationStack(path: $signInPath) {
                SignInView(sessionStore: sessionStore, analytics: dependencies.analytics)
                    .navigationDestination(for: OnboardingViewModel.Step.self) { _ in
                        OnboardingView(
                            viewModel: dependencies.makeOnboardingViewModel(sessionStore: sessionStore)
                        ) { pendingInviteClinicID = nil }
                    }
                    .navigationDestination(for: PasswordResetRoute.self) { resetPassword($0) }
            }
        case .needsClinic(let account):
            NavigationStack {
                OnboardingView(viewModel: dependencies.makeOnboardingViewModel(
                    sessionStore: sessionStore, startingAt: .clinic, account: account
                )) { pendingInviteClinicID = nil }
            }
        case .signedIn(let session) where pendingInviteClinicID == session.clinicID:
            NavigationStack {
                OnboardingView(viewModel: dependencies.makeOnboardingViewModel(
                    sessionStore: sessionStore, startingAt: .invite, clinicID: session.clinicID
                )) { pendingInviteClinicID = nil }
            }
        case .signedIn(let session):
            AppTabsView(router: router, session: session)
                .environment(router)
                .environment(sessionStore)
                .environment(\.session, session)
                .environment(\.membershipCheck, MembershipCheckAction { [sessionStore] in
                    await sessionStore.revalidateIfDue()
                })
                .pushNotifications(dependencies.push, session: session, open: open)
                // A changed role rebuilds the screens, so the controls follow it at once (MS-138), and so do a new
                // clinic name, currency or time zone saved in Clinic settings (MS-139). The router keeps the paths.
                .id([session.role.rawValue, session.clinicName, session.currency, session.timeZone])
        }
    }

    /// What a tapped notification opens, as its alert's row in Activity does (MS-133, MS-144): the product on the
    /// Inventory tab, or Receive delivery on Home.
    private func open(_ link: NotificationLink) {
        switch link {
        case .product(let productID):
            router.popToRoot(on: .inventory)
            router.selectedTab = .inventory
            router.push(InventoryRoute.product(productID), on: .inventory)
        case .delivery:
            router.popToRoot(on: .home)
            router.selectedTab = .home
            // Receiving is admin-only (MS-126): for a member who is no longer an admin, the link stops at Home.
            guard let session = sessionStore.session, session.isAdmin else { return }
            // Receiving is a write: in read-only mode the sheet says why instead (MS-142).
            if !session.canWrite(at: dependencies.clock.now) {
                router.isReadOnlySheetPresented = true
            } else {
                router.push(HomeRoute.receive, on: .home)
            }
        }
    }

    /// Reset password, from Sign in's Forgot password or from an expired reset link (MS-113).
    private func resetPassword(_ route: PasswordResetRoute) -> some View {
        ResetPasswordView(viewModel: dependencies.makeResetPasswordViewModel(email: route.email))
    }
}

/// The four tabs, each a `NavigationStack` kept alive so scroll positions survive switching, under the
/// drawn `AppTabBar`. The bar disappears while a tab shows a pushed screen (PRD §3).
struct AppTabsView: View {
    @Environment(\.appDependencies) private var dependencies
    @Bindable var router: AppRouter
    let session: Session
    /// Measured from the bar, so a tab's root screen keeps its content above it.
    @State private var tabBarHeight: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(AppTab.allCases) { tab in
                let isSelected = tab == router.selectedTab
                NavigationStack(path: router.pathBinding(for: tab)) {
                    root(of: tab)
                        // The bar's safe-area inset does not reach the screens a NavigationStack hosts, so the
                        // root gets it here: the last row scrolls clear of the bar, and pinned bars and the
                        // round + sit above it.
                        .safeAreaPadding(.bottom, tabBarHeight)
                        .tabPage()
                }
                // VoiceOver skips the tabs under the chosen one: `accessibilityHidden` here would not reach the
                // screens the stack hosts, so its root (`tabPage()`) and pushed screens (`tabDestination`) read this.
                .environment(\.isTabSelected, isSelected)
                .opacity(isSelected ? 1 : 0)
                .allowsHitTesting(isSelected)
                .zIndex(isSelected ? 1 : 0)
            }
        }
        .toastHost()
        .environment(\.writeAccess, WriteAccess(session: session, clock: dependencies.clock) { [router] in
            router.isReadOnlySheetPresented = true
        })
        .msSheet(isPresented: $router.isReadOnlySheetPresented) {
            ReadOnlySheet(isAdmin: session.isAdmin, onBilling: openBilling) {
                router.isReadOnlySheetPresented = false
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if router.path(for: router.selectedTab).isEmpty {
                AppTabBar(selected: router.selectedTab, toBuyCount: router.toBuyCount) { router.select($0) }
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        tabBarHeight = height
                    }
            }
        }
        .background(Color.ms.canvas)
    }

    /// "Go to Billing" (MS-142): Billing on Home's stack, the status screen; the card is added from the billing email.
    private func openBilling() {
        router.isReadOnlySheetPresented = false
        router.popToRoot(on: .home)
        router.selectedTab = .home
        router.push(HomeRoute.billing, on: .home)
    }

    @ViewBuilder private func root(of tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView(session: session, dependencies: dependencies)
        case .inventory: InventoryListView(session: session, dependencies: dependencies)
        case .procedures: ProceduresView(session: session, dependencies: dependencies)
        case .toBuy: ToBuyView(session: session, dependencies: dependencies)
        }
    }
}

#Preview("Signed in") {
    RootView(sessionStore: SessionStore(auth: PreviewAuthService(session: .demo), state: .signedIn(.demo)))
}

#Preview("Signed out") {
    RootView(sessionStore: SessionStore(auth: PreviewAuthService(session: nil), state: .signedOut))
}
