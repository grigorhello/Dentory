import SwiftUI

/// A labelled switch: label leading, 40 × 24 pill trailing. Any `Toggle` can use `.toggleStyle(.ms)`.
struct MSToggle: View {
    let label: String
    @Binding var isOn: Bool

    init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        _isOn = isOn
    }

    var body: some View {
        Toggle(label, isOn: $isOn).toggleStyle(.ms)
    }
}

struct MSToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: Spacing.md) {
                configuration.label
                    .textStyle(.body16)
                    .foregroundStyle(Color.ms.ink)
                Spacer(minLength: Spacing.sm)
                track(isOn: configuration.isOn)
            }
            .frame(minHeight: ControlHeight.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .animation(Motion.baseAnimation, value: configuration.isOn)
    }

    private func track(isOn: Bool) -> some View {
        Capsule()
            .fill(isOn ? Color.ms.primary : Color.ms.mute)
            .frame(width: 40, height: 24)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.ms.canvas)
                    .frame(width: 18, height: 18)
                    .msShadow(Shadow.soft)
                    .padding(3)
            }
    }
}

extension ToggleStyle where Self == MSToggleStyle {
    static var ms: MSToggleStyle { MSToggleStyle() }
}

#Preview("Toggles") {
    @Previewable @State var isOn = true
    VStack(spacing: Spacing.sm) {
        MSToggle("Expiry alerts", isOn: $isOn)
        MSToggle("Low stock alerts", isOn: .constant(false))
        MSToggle("Disabled", isOn: .constant(true)).disabled(true)
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
