import SwiftUI

/// Read-only mode at the controls (MS-142, PRD §9, MS-100 G5 and D18): a write entry point (Start procedure, Adjust,
/// Add to buy, Dispose…) runs its action while the clinic may change things, and otherwise opens the read-only sheet,
/// which `AppTabsView` presents. Reading needs nothing from it; the database refuses the writes as well.
struct WriteAccess: Sendable {
    let session: Session?
    let clock: Clock
    let showReadOnly: @MainActor @Sendable () -> Void

    var canWrite: Bool {
        session?.canWrite(at: clock.now) ?? true
    }

    /// The action, or the read-only sheet in its place.
    @MainActor
    func perform(_ action: () -> Void) {
        if canWrite {
            action()
        } else {
            showReadOnly()
        }
    }
}

private struct WriteAccessKey: EnvironmentKey {
    static let defaultValue = WriteAccess(session: nil, clock: SystemClock(), showReadOnly: {})
}

extension EnvironmentValues {
    /// Set by `AppTabsView` for the signed-in session.
    var writeAccess: WriteAccess {
        get { self[WriteAccessKey.self] }
        set { self[WriteAccessKey.self] = newValue }
    }
}
