import SwiftUI

/// Loads on appear, on pull-to-refresh and when the app returns to the foreground (PRD §9: screens
/// refresh on return to foreground). Every list screen applies it with its view model's `load()`.
struct ReloadOnReturnModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let reload: () async -> Void

    func body(content: Content) -> some View {
        content
            .task { await reload() }
            .refreshable { await reload() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await reload() }
                }
            }
    }
}

extension View {
    func reloadOnReturn(_ reload: @escaping () async -> Void) -> some View {
        modifier(ReloadOnReturnModifier(reload: reload))
    }
}
