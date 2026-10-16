import SwiftUI

@main
struct MediSaveApp: App {
    private let dependencies: AppDependencies
    @State private var sessionStore: SessionStore

    init() {
        // `-uiTesting` runs the app on the preview doubles: no network, a signed-in demo admin.
        // `-offline` with it makes the network monitor report no connection; `-signedOut` starts on Sign in.
        let arguments = ProcessInfo.processInfo.arguments
        let dependencies = arguments.contains("-uiTesting")
            ? AppDependencies.preview(
                signedIn: !arguments.contains("-signedOut"), isConnected: !arguments.contains("-offline")
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
