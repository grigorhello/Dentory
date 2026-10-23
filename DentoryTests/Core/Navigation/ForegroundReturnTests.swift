import SwiftUI
import Testing
@testable import Dentory

/// PRD §9, screens refresh on return to the foreground: iOS reports background → inactive → active, and only that
/// return reloads.
struct ForegroundReturnTests {
    private func returns(_ phases: [ScenePhase]) -> [Bool] {
        var watch = ForegroundReturn()
        return phases.map { watch.phaseChanged(to: $0) }
    }

    @Test func aReturnThroughInactiveReloadsOnce() {
        #expect(returns([.inactive, .background, .inactive, .active, .active]) == [false, false, false, true, false])
    }

    @Test func anInactiveSpellAloneIsNoReturn() {
        #expect(returns([.inactive, .active]) == [false, false], "Control Center, a system sheet")
    }

    @Test func aDirectReturnStillCounts() {
        #expect(returns([.background, .active]) == [false, true])
    }
}
