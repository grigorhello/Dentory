import SwiftUI

/// A 24 pt checkbox with a label and an optional description. Any `Toggle` can use `.toggleStyle(.msCheckbox)`.
struct MSCheckbox: View {
    let label: String
    var description: String?
    @Binding var isOn: Bool

    init(_ label: String, description: String? = nil, isOn: Binding<Bool>) {
        self.label = label
        self.description = description
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(label).textStyle(.body16).foregroundStyle(Color.ms.ink)
                if let description {
                    Text(description).textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
                }
            }
        }
        .toggleStyle(.msCheckbox)
    }
}

struct MSCheckboxStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: Spacing.md) {
                CheckboxBox(isOn: configuration.isOn)
                configuration.label
                Spacer(minLength: 0)
            }
            .frame(minHeight: ControlHeight.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "Checked" : "Unchecked")
        .animation(Motion.fastAnimation, value: configuration.isOn)
    }
}

/// The box alone, 24 pt: primary fill with a check when on, ink hairline on canvas when off.
struct CheckboxBox: View {
    let isOn: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            .fill(isOn ? Color.ms.primary : Color.ms.surfacePage)
            .frame(width: 24, height: 24)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(isOn ? Color.ms.primary : Color.ms.ink, lineWidth: 1)
            )
            .overlay {
                if isOn {
                    CheckmarkShape()
                        .stroke(
                            Color.ms.onPrimary,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 13, height: 13)
                }
            }
    }
}

/// The Lucide check path (`M20 6 9 17l-5-5`) on a unit square.
nonisolated struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.1))
        return path
    }
}

extension ToggleStyle where Self == MSCheckboxStyle {
    static var msCheckbox: MSCheckboxStyle { MSCheckboxStyle() }
}

#Preview("Checkboxes") {
    @Previewable @State var isOn = true
    VStack(spacing: Spacing.sm) {
        MSCheckbox("Endo file kit #15-40", description: "Current 1 · target 5 · Patterson", isOn: $isOn)
        MSCheckbox("Composite A2", isOn: .constant(false))
        MSCheckbox("Disabled", isOn: .constant(true)).disabled(true)
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
