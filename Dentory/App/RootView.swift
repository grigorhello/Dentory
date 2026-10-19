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
    /// `-onboarding account` (screenshots) starts Sign in with step 1 already pushed.
    @State private var signInPath: [OnboardingViewModel.Step]
    /// The token of the invitation link that opened the app: the Join screen (f5) shows whatever the
    /// session is, and the new session replaces the old one when the invitee joins (MS-112).
    @State private var invitationToken: String?

    init(sessionStore: SessionStore, startsOnSignUp: Bool = false, invitationToken: String? = nil) {
        self.sessionStore = sessionStore
        _signInPath = State(initialValue: startsOnSignUp ? [.account] : [])
        _invitationToken = State(initialValue: invitationToken)
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
            } else {
                sessionContent
            }
        }
        .onOpenURL { url in
            if let token = InvitationLink.token(from: url) {
                invitationToken = token
            }
        }
        .onAppear {
            guard !didReadProgress else { return }
            didReadProgress = true
            pendingInviteClinicID = dependencies.onboardingProgress.pendingInviteClinicID()
        }
        .onChange(of: sessionStore.state) { _, state in
            // Step 2 just finished in this launch: step 3 shows before the tabs.
            if case .signedIn = state {
                pendingInviteClinicID = dependencies.onboardingProgress.pendingInviteClinicID()
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
                .environment(\.session, session)
        }
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
