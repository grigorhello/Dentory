import Foundation

/// The rules behind a quantity stepper (PRD §7): never below the minimum (0 by default), and a value that differs
/// from its reference (the default or estimate) is shown in primary blue. Kept out of the view so it can be tested.
nonisolated struct QuantityStepperModel: Equatable, Sendable {
    var value: Int
    /// The default or estimated quantity the value is compared against; nil when there is none.
    let reference: Int?
    /// The caller's own answer for the blue, used instead of `reference` when the comparison is with something
    /// a whole number cannot hold, such as a count against a fractional or negative estimate (MS-121).
    let highlight: Bool?
    let minimum: Int

    init(value: Int, reference: Int? = nil, highlight: Bool? = nil, minimum: Int = 0) {
        self.value = max(value, minimum)
        self.reference = reference
        self.highlight = highlight
        self.minimum = minimum
    }

    var canDecrement: Bool { value > minimum }

    /// True when the value differs from the reference.
    var differsFromReference: Bool {
        guard let reference else { return false }
        return value != reference
    }

    /// True when the value should be drawn in primary blue.
    var isHighlighted: Bool {
        highlight ?? differsFromReference
    }

    /// What VoiceOver reads after the item's name: the number, and "changed" while it is drawn in blue.
    var spokenValue: String {
        isHighlighted ? "\(value), changed" : "\(value)"
    }

    mutating func increment() {
        value += 1
    }

    mutating func decrement() {
        value = max(value - 1, minimum)
    }
}
