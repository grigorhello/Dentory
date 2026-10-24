import Foundation
import Testing
@testable import Dentory

/// MS-142: a write entry point runs its action, or opens the read-only sheet in its place.
@MainActor
struct WriteAccessTests {
    /// Counts the read-only sheets opened.
    @MainActor
    final class Sheets {
        var count = 0
    }

    private func session(trialEndsIn days: Double) -> Session {
        var session = Session.demo
        session.trialEndsAt = Session.demoNow.addingTimeInterval(days * 86_400)
        return session
    }

    @Test func aWritableClinicRunsTheAction() {
        var ran = false
        let sheets = Sheets()
        let access = WriteAccess(session: session(trialEndsIn: 10), clock: FixedClock(Session.demoNow)) {
            sheets.count += 1
        }
        access.perform { ran = true }
        #expect(ran)
        #expect(sheets.count == 0)
    }

    @Test func aReadOnlyClinicOpensTheSheetInstead() {
        var ran = false
        let sheets = Sheets()
        let access = WriteAccess(session: session(trialEndsIn: -1), clock: FixedClock(Session.demoNow)) {
            sheets.count += 1
        }
        #expect(!access.canWrite)
        access.perform { ran = true }
        #expect(!ran)
        #expect(sheets.count == 1)
    }

    @Test func withoutASessionNothingIsHeldBack() {
        var ran = false
        WriteAccess(session: nil, clock: FixedClock(Session.demoNow)) {}.perform { ran = true }
        #expect(ran)
    }
}
