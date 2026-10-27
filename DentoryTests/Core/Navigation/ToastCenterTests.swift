import Foundation
import Testing
@testable import Dentory

@MainActor
struct ToastCenterTests {
    @Test func showsOneToastAndANewOneReplacesIt() {
        let center = ToastCenter(duration: 60)
        center.show("Adjustment saved", detail: "54 → 52")
        #expect(center.current?.title == "Adjustment saved")
        #expect(center.current?.detail == "54 → 52")
        #expect(center.current?.hasUndo == false)
        center.show("Out of stock")
        #expect(center.current?.title == "Out of stock")
    }

    @Test func undoRunsTheCallbackOnceAndHidesTheToast() {
        let center = ToastCenter(duration: 60)
        var undone = 0
        center.show("Added to To buy", undo: { undone += 1 })
        #expect(center.current?.hasUndo == true)
        center.undo()
        center.undo()
        #expect(undone == 1)
        #expect(center.current == nil)
    }

    @Test func hidesItselfAfterTheDuration() async throws {
        let center = ToastCenter(duration: 0.05)
        center.show("Saved")
        #expect(center.current != nil)
        try await Task.sleep(for: .milliseconds(300))
        #expect(center.current == nil)
    }

    @Test func aNewToastRestartsTheTimerOfTheOld() async throws {
        let center = ToastCenter(duration: 0.1)
        center.show("First")
        try await Task.sleep(for: .milliseconds(60))
        center.show("Second")
        try await Task.sleep(for: .milliseconds(60))
        #expect(center.current?.title == "Second")
    }

    @Test func dismissHidesTheToast() {
        let center = ToastCenter(duration: 60)
        center.show("Saved")
        center.dismiss()
        #expect(center.current == nil)
    }

    @Test func voiceOverAnnouncesEachToastWithItsUndo() {
        var announced: [String] = []
        let center = ToastCenter(duration: 60, announce: { announced.append($0) })
        center.show("Adjustment saved", detail: "54 → 52", undo: {})
        center.show("Out of stock")
        #expect(announced == ["Adjustment saved. 54 → 52. Undo available", "Out of stock"])
    }

    @Test func aToastStaysLongerWhileVoiceOverRuns() async throws {
        let center = ToastCenter(
            duration: 0.05, voiceOverDuration: 60, isVoiceOverRunning: { true }, announce: { _ in }
        )
        center.show("Added to To buy", undo: {})
        try await Task.sleep(for: .milliseconds(300))
        #expect(center.current?.title == "Added to To buy", "Long enough to reach Undo")
    }
}
