import SwiftUI

/// Loads on appear, on pull-to-refresh and when the app returns to the foreground (PRD §9: screens
/// refresh on return to foreground). Every list screen applies it with its view model's `load()`; a screen that
/// already loads on appear its own way (History's `.task(id:)` per chip) passes `loadsOnAppear: false`. Each load also
/// checks the member's access, so someone removed from the clinic is signed out on their next request (MS-138).
struct ReloadOnReturnModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.membershipCheck) private var membershipCheck
    @State private var foregroundReload: Task<Void, Never>?
    @State private var foregroundReturn = ForegroundReturn()
    let loadsOnAppear: Bool
    let reload: () async -> Void

    func body(content: Content) -> some View {
        content
            .task {
                guard loadsOnAppear else { return }
                await load()
            }
            .refreshable { await load() }
            .onChange(of: scenePhase) { _, phase in
                // Only a return from the background, which passes through inactive; the launch is covered by `.task`.
                guard foregroundReturn.phaseChanged(to: phase) else { return }
                foregroundReload?.cancel()
                foregroundReload = Task { await load() }
            }
            .onDisappear { foregroundReload?.cancel() }
    }

    private func load() async {
        async let check: Void = membershipCheck()
        await reload()
        await check
    }
}

extension View {
    func reloadOnReturn(loadsOnAppear: Bool = true, _ reload: @escaping () async -> Void) -> some View {
        modifier(ReloadOnReturnModifier(loadsOnAppear: loadsOnAppear, reload: reload))
    }
}
