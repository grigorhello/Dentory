import Foundation
import Testing
@testable import Dentory

struct SkeletonRowTests {
    private let breath = Motion.pulse * 2

    @Test func pulseIsFullAtTheStartOfABreath() {
        let start = Date(timeIntervalSinceReferenceDate: breath * 10)
        #expect(abs(SkeletonRow.opacity(at: start) - 1) < 0.001)
    }

    @Test func pulseIsDimmestHalfwayThroughABreath() {
        let halfway = Date(timeIntervalSinceReferenceDate: breath * 10 + Motion.pulse)
        #expect(abs(SkeletonRow.opacity(at: halfway) - 0.45) < 0.001)
    }

    @Test func pulseStaysWithinItsRange() {
        for step in 0..<60 {
            let date = Date(timeIntervalSinceReferenceDate: Double(step) * breath / 60)
            let opacity = SkeletonRow.opacity(at: date)
            #expect(opacity >= 0.45 && opacity <= 1)
        }
    }
}
