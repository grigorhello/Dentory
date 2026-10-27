import SwiftUI

/// 40 pt − and + around a centred value (PRD §7), their 24 pt icons as the frames draw them (f13, f15, f18, f25). The
/// value turns primary blue when it differs from `reference` and never goes below `minimum`. `identifier` is the
/// Appendix B row id; the parts get `.dec`, `.value` and `.inc`. VoiceOver reads the buttons with `name` ("Increase
/// Septocaine 4%, 2") and the number as an adjustable value, raised and lowered with a swipe up or down (MS-149).
struct QuantityStepper: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Binding var value: Int
    var reference: Int?
    /// Decides the blue instead of `reference` when the caller compares with something the stepper cannot
    /// hold, such as a count against a fractional or negative estimate (MS-121).
    var isHighlighted: Bool?
    var minimum = 0
    /// What the number counts, as VoiceOver names it: the product ("Septocaine 4% 1:100,000").
    let name: String
    let identifier: String

    init(
        value: Binding<Int>,
        reference: Int? = nil,
        isHighlighted: Bool? = nil,
        minimum: Int = 0,
        name: String,
        identifier: String
    ) {
        _value = value
        self.reference = reference
        self.isHighlighted = isHighlighted
        self.minimum = minimum
        self.name = name
        self.identifier = identifier
    }

    private var model: QuantityStepperModel {
        QuantityStepperModel(value: value, reference: reference, highlight: isHighlighted, minimum: minimum)
    }

    var body: some View {
        HStack(spacing: 0) {
            stepButton(.minus, label: "Decrease \(name)", id: "dec", isEnabled: model.canDecrement, action: decrement)
            // The blue is not the only cue: underlined when colors should not carry meaning, "changed" for VoiceOver.
            // The number is never cut: a long one widens the stepper and the row's label wraps instead (MS-149).
            Text("\(model.value)")
                .underline(model.isHighlighted && differentiateWithoutColor)
                .textStyle(.bodyStrong16)
                .monospacedDigit()
                .foregroundStyle(model.isHighlighted ? Color.ms.primary : Color.ms.ink)
                .fixedSize()
                // As tall as the buttons, so the number VoiceOver reaches by touch is a 44 pt target too: the shape
                // gives the element the frame's size, which would otherwise be the text's.
                .frame(minWidth: 36, minHeight: ControlHeight.hitTarget)
                .accessibilityElement(children: .ignore)
                .contentShape(.accessibility, Rectangle())
                .accessibilityLabel(name)
                .accessibilityValue(model.spokenValue)
                .accessibilityAdjustableAction { direction in
                    if direction == .increment {
                        increment()
                    } else if direction == .decrement {
                        decrement()
                    }
                }
                .accessibilityIdentifier("\(identifier).value")
            stepButton(.plus, label: "Increase \(name)", id: "inc", isEnabled: true, action: increment)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func increment() {
        var model = model
        model.increment()
        value = model.value
    }

    private func decrement() {
        var model = model
        model.decrement()
        value = model.value
    }

    private func stepButton(
        _ icon: Icon,
        label: String,
        id: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            IconView(icon, size: 24)
        }
        .buttonStyle(StepperButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityValue("\(model.value)")
        .accessibilityIdentifier("\(identifier).\(id)")
    }
}

/// The 40 × 40 canvas square with a line border and 6 pt radius; darkens on press, fades when disabled.
struct StepperButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.ms.ink)
            .frame(width: 40, height: 40)
            .background(
                configuration.isPressed ? Color.ms.canvasSunken : Color.ms.surfacePage,
                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(Color.ms.line, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .frame(width: ControlHeight.hitTarget, height: ControlHeight.hitTarget)
            .contentShape(Rectangle())
            .animation(Motion.fastAnimation, value: configuration.isPressed)
    }
}

#Preview("Stepper") {
    @Previewable @State var quantity = 2
    @Previewable @State var count = 0
    VStack(spacing: Spacing.lg) {
        QuantityStepper(value: $quantity, reference: 2, name: "Septocaine 4%", identifier: "preview.row[1]")
        QuantityStepper(value: $count, name: "Gauze 2x2", identifier: "preview.row[2]")
    }
    .padding(Spacing.page)
    .background(Color.ms.surfaceCard)
}
