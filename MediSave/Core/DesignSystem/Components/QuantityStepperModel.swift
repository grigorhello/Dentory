import Foundation

/// The rules behind a quantity stepper (PRD §7): never below the minimum (0 by default), and a value that differs
/// from its reference (the default or estimate) is shown in primary blue. Kept out of the view so it can be tested.
nonisolated struct QuantityStepperModel: Equatable, Sendable {
    var value: Int
    /// The default or estimated quantity the value is compared against; nil when there is none.
    let reference: Int?
    let minimum: Int

    init(value: Int, reference: Int? = nil, minimum: Int = 0) {
        self.value = max(value, minimum)
        self.reference = reference
        self.minimum = minimum
    }

    var canDecrement: Bool { value > minimum }

    /// True when the value should be drawn in primary blue.
    var differsFromReference: Bool {
        guard let reference else { return false }
        return value != reference
    }

    mutating func increment() {
        value += 1
    }

    mutating func decrement() {
        value = max(value - 1, minimum)
    }
}
