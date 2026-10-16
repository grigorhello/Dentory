import SwiftUI

@main
struct MediSaveApp: App {
    private let dependencies: AppDependencies
    @State private var sessionStore: SessionStore

    init() {
        // `-uiTesting` runs the app on the preview doubles: no network, a signed-in demo admin.
        let dependencies = ProcessInfo.processInfo.arguments.contains("-uiTesting")
            ? AppDependencies.preview()
            : AppDependencies.live()
        self.dependencies = dependencies
        _sessionStore = State(initialValue: SessionStore(auth: dependencies.auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView(sessionStore: sessionStore)
                .environment(\.appDependencies, dependencies)
                .task { await sessionStore.restore() }
        }
    }
}
