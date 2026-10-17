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
}
