import SwiftUI

/// Loads on appear, on pull-to-refresh and when the app returns to the foreground (PRD §9: screens
/// refresh on return to foreground). Every list screen applies it with its view model's `load()`.
struct ReloadOnReturnModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var foregroundReload: Task<Void, Never>?
    let reload: () async -> Void

    func body(content: Content) -> some View {
        content
            .task { await reload() }
            .refreshable { await reload() }
            .onChange(of: scenePhase) { previous, phase in
                // Only a return from the background; the launch transition is covered by `.task`.
                guard previous == .background, phase == .active else { return }
                foregroundReload?.cancel()
                foregroundReload = Task { await reload() }
            }
            .onDisappear { foregroundReload?.cancel() }
    }
}

extension View {
    func reloadOnReturn(_ reload: @escaping () async -> Void) -> some View {
        modifier(ReloadOnReturnModifier(reload: reload))
    }
}
