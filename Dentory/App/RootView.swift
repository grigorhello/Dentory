import SwiftUI

/// Signed out shows Sign in (MS-110); signed in shows the four tabs, each with its own
/// `NavigationStack` and path from `AppRouter`.
struct RootView: View {
    @Environment(\.appDependencies) private var dependencies
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
            }
        }
        .onAppear {
            guard !didReadProgress else { return }
            didReadProgress = true
            pendingInviteClinicID = dependencies.onboardingProgress.pendingInviteClinicID()
        }
        .onChange(of: sessionStore.state) { _, state in
            switch state {
            case .signedIn:
                // Step 2 just finished in this launch: step 3 shows before the tabs.
                pendingInviteClinicID = dependencies.onboardingProgress.pendingInviteClinicID()
            case .signedOut:
                // Whoever signs in next starts on Home, with nothing pushed or filtered (MS-137).
                router.reset()
            default:
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
                SignInView(sessionStore: sessionStore)
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
            AppTabsView(router: router)
                .environment(router)
                .environment(sessionStore)
                .environment(\.session, session)
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
    @Environment(\.session) private var session
    @Bindable var router: AppRouter
    /// Measured from the bar; root screens read it as `tabBarInset` to float controls above the bar.
    @State private var tabBarHeight: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(AppTab.allCases) { tab in
                let isSelected = tab == router.selectedTab
                NavigationStack(path: router.pathBinding(for: tab)) {
                    if tab == .home, let session {
                        HomeView(session: session, dependencies: dependencies)
                    } else if tab == .inventory, let session {
                        InventoryListView(session: session, dependencies: dependencies)
                    } else if tab == .procedures, let session {
                        ProceduresView(session: session, dependencies: dependencies)
                    } else if tab == .toBuy, let session {
                        ToBuyView(session: session, dependencies: dependencies)
                    } else {
                        TabPlaceholderView(tab: tab)
                    }
                }
                .environment(\.tabBarInset, router.path(for: tab).isEmpty ? tabBarHeight : 0)
                .opacity(isSelected ? 1 : 0)
                .allowsHitTesting(isSelected)
                .accessibilityHidden(!isSelected)
                .zIndex(isSelected ? 1 : 0)
            }
        }
        .toastHost()
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
}

#Preview("Signed in") {
    RootView(sessionStore: SessionStore(auth: PreviewAuthService(session: .demo), state: .signedIn(.demo)))
}

#Preview("Signed out") {
    RootView(sessionStore: SessionStore(auth: PreviewAuthService(session: nil), state: .signedOut))
}
