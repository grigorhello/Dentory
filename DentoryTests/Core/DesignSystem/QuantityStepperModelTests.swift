import Testing
@testable import Dentory

struct QuantityStepperModelTests {
    @Test func decrementStopsAtZero() {
        var model = QuantityStepperModel(value: 1)
        model.decrement()
        #expect(model.value == 0)
        #expect(model.canDecrement == false)
        model.decrement()
        #expect(model.value == 0)
    }

    @Test func initialValueIsClampedToMinimum() {
        let model = QuantityStepperModel(value: -3)
        #expect(model.value == 0)
    }

    @Test func customMinimumIsRespected() {
        var model = QuantityStepperModel(value: 1, minimum: 1)
        model.decrement()
        #expect(model.value == 1)
        model.increment()
        #expect(model.value == 2)
        #expect(model.canDecrement)
    }

    @Test func valueDiffersFromReferenceAfterAChange() {
        var model = QuantityStepperModel(value: 2, reference: 2)
        #expect(model.differsFromReference == false)
        model.increment()
        #expect(model.differsFromReference)
        model.decrement()
        #expect(model.differsFromReference == false)
    }

    @Test func noReferenceNeverDiffers() {
        var model = QuantityStepperModel(value: 2)
        model.increment()
        #expect(model.differsFromReference == false)
    }

    @Test func theCallersHighlightWinsOverTheReference() {
        // A count of 0 against a negative estimate: the value differs from the reference, yet nothing was counted.
        let untouched = QuantityStepperModel(value: 0, reference: -2, highlight: false)
        #expect(untouched.differsFromReference)
        #expect(untouched.isHighlighted == false)
        // 12 counted against an estimate of 12.5 shown as 12: a correction the reference cannot see.
        let counted = QuantityStepperModel(value: 12, reference: 12, highlight: true)
        #expect(counted.isHighlighted)
        #expect(QuantityStepperModel(value: 3, reference: 2).isHighlighted, "Without a highlight the reference decides")
    }
}
