import SwiftUI

@main
struct DentoryApp: App {
    private let dependencies: AppDependencies
    @State private var sessionStore: SessionStore

    init() {
        // `-uiTesting` runs the app on the preview doubles: no network, a signed-in demo admin.
        // `-offline` with it makes the network monitor report no connection; `-signedOut` starts on Sign in;
        // `-staff` signs in as the Staff member; `-onboarding account|clinic|invite` opens admin sign-up there.
        let arguments = ProcessInfo.processInfo.arguments
        let onboarding = UserDefaults.standard.string(forKey: "onboarding")
        let dependencies = arguments.contains("-uiTesting")
            ? AppDependencies.preview(
                signedIn: !arguments.contains("-signedOut") && onboarding != "account",
                isConnected: !arguments.contains("-offline"),
                role: arguments.contains("-staff") ? .staff : .admin,
                onboarding: onboarding
            )
            : AppDependencies.live()
        self.dependencies = dependencies
        _sessionStore = State(initialValue: SessionStore(auth: dependencies.auth))
        dependencies.reporter.start()
        dependencies.writes.startWatchingNetwork()
    }

    var body: some Scene {
        WindowGroup {
            RootView(sessionStore: sessionStore)
                .environment(\.appDependencies, dependencies)
                .task { await sessionStore.restore() }
        }
    }
}
