import SwiftUI

/// Signed out shows a placeholder until MS-110 brings Sign in; signed in shows the four tabs
/// (MS-103 replaces them with the real shell).
struct RootView: View {
    let sessionStore: SessionStore
    @State private var selection: AppTab = .home

    var body: some View {
        switch sessionStore.state {
        case .restoring:
            ProgressView()
                .tint(Color.ms.primary)
                .accessibilityIdentifier("root.restoring")
        case .signedOut:
            SignedOutPlaceholderView()
        case .signedIn:
            TabView(selection: $selection) {
                ForEach(AppTab.allCases) { tab in
                    NavigationStack {
                        TabPlaceholderView(tab: tab)
                            .navigationTitle(tab.title)
                    }
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
                    .accessibilityIdentifier(tab.accessibilityIdentifier)
                }
            }
        }
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
