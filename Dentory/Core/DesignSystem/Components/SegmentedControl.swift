import SwiftUI

/// One segment: its value, label and optional count ("To buy · 3").
nonisolated struct SegmentOption<Value: Hashable & Sendable>: Identifiable, Sendable {
    let value: Value
    let label: String
    var count: Int?

    init(_ value: Value, label: String, count: Int? = nil) {
        self.value = value
        self.label = label
        self.count = count
    }

    var id: Value { value }

    var text: String {
        count.map { "\(label) · \($0)" } ?? label
    }
}

/// Two or three views in a cream-soft track (PRD §7). Set the Appendix B id (`order.seg`) on the control.
struct SegmentedControl<Value: Hashable & Sendable>: View {
    @Binding var selection: Value
    let options: [SegmentOption<Value>]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                segment(option)
            }
        }
        .padding(Spacing.xs)
        .background(Color.ms.surfaceCard, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        // The selected pill fades in place (PRD §7: fades and color only, nothing slides).
        .animation(Motion.baseAnimation, value: selection)
    }

    private func segment(_ option: SegmentOption<Value>) -> some View {
        let isSelected = option.value == selection
        return Button {
            selection = option.value
        } label: {
            Text(option.text)
                .textStyle(isSelected ? .bodyStrong16 : .body16)
                .foregroundStyle(isSelected ? Color.ms.ink : Color.ms.textBody)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    RoundedRectangle(cornerRadius: Radius.md - Spacing.xs, style: .continuous)
                        .fill(Color.ms.surfacePage)
                        .msShadow(Shadow.soft)
                        .opacity(isSelected ? 1 : 0)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview("Segments") {
    @Previewable @State var tab = "toBuy"
    @Previewable @State var window = 30
    VStack(spacing: Spacing.lg) {
        SegmentedControl(selection: $tab, options: [
            SegmentOption("toBuy", label: "To buy", count: 3),
            SegmentOption("ordered", label: "Ordered", count: 3),
            SegmentOption("received", label: "Received", count: 1)
        ])
        SegmentedControl(selection: $window, options: [30, 60, 90].map { SegmentOption($0, label: "\($0) days") })
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
