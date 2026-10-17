import SwiftUI

/// Signed out shows Sign in (MS-110); signed in shows the four tabs, each with its own
/// `NavigationStack` and path from `AppRouter`.
struct RootView: View {
    let sessionStore: SessionStore
    @State private var router = AppRouter()

    var body: some View {
        switch sessionStore.state {
        case .restoring:
            ProgressView()
                .tint(Color.ms.primary)
                .accessibilityIdentifier("root.restoring")
        case .signedOut:
            SignInView(sessionStore: sessionStore)
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

    var body: some View {
        ZStack {
            ForEach(AppTab.allCases) { tab in
                let isSelected = tab == router.selectedTab
                NavigationStack(path: router.pathBinding(for: tab)) {
                    if tab == .home, let session {
                        HomeView(session: session, dependencies: dependencies)
                    } else {
                        TabPlaceholderView(tab: tab)
                    }
                }
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
