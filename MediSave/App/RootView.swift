import SwiftUI

/// Signed out shows a placeholder until MS-110 brings Sign in; signed in shows the four tabs, each
/// with its own `NavigationStack` and path from `AppRouter`.
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
            SignedOutPlaceholderView()
        case .signedIn(let session):
            AppTabsView(router: router)
                .environment(router)
                .environment(\.session, session)
        }
    }
}

/// The tab bar (f25): Lucide icons, active tab in primary blue, red count badge on To buy.
struct AppTabsView: View {
    @Bindable var router: AppRouter

    var body: some View {
        TabView(selection: selection) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: router.pathBinding(for: tab)) {
                    TabPlaceholderView(tab: tab)
                }
                .tabItem {
                    Label {
                        Text(tab.title)
                    } icon: {
                        tab.icon.image
                    }
                }
                .tag(tab)
                .badge(tab == .toBuy ? router.toBuyCount : 0)
                .accessibilityIdentifier(tab.accessibilityIdentifier)
            }
        }
        .tint(Color.ms.primary)
    }

    /// Reselecting the current tab pops it to its root, as iOS does.
    private var selection: Binding<AppTab> {
        Binding(
            get: { router.selectedTab },
            set: { router.select($0) }
        )
    }
}

/// Stands in for the Sign in screen (f1) until MS-110.
struct SignedOutPlaceholderView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("Sign in").textStyle(.display32).foregroundStyle(Color.ms.ink)
            Text("The sign-in screen arrives with MS-110.").textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ms.canvas)
        .accessibilityIdentifier("signin.placeholder")
    }
}

#Preview("Signed in") {
    RootView(sessionStore: SessionStore(auth: PreviewAuthService(session: .demo), state: .signedIn(.demo)))
}

#Preview("Signed out") {
    RootView(sessionStore: SessionStore(auth: PreviewAuthService(session: nil), state: .signedOut))
}
