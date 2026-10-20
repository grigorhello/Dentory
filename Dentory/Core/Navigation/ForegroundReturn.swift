import SwiftUI

/// Tells a return from the background apart from the app's other phase changes. iOS goes background → inactive →
/// active, so the return is the first `.active` after a `.background`; an inactive spell alone (Control Center, a system
/// sheet) is not one.
nonisolated struct ForegroundReturn: Equatable, Sendable {
    private var wasInBackground = false

    /// True when this phase completes a return from the background.
    mutating func phaseChanged(to phase: ScenePhase) -> Bool {
        switch phase {
        case .background:
            wasInBackground = true
            return false
        case .active:
            defer { wasInBackground = false }
            return wasInBackground
        default:
            return false
        }
    }
}
