import SwiftUI

/// A month of a year, what `MSMonthField` picks (expiry has month precision, PRD §4).
nonisolated struct YearMonth: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

/// A month and year drawn like a text field. Tapping it opens month and year wheels under the field, set to
/// the chosen month, or to `opening` (which it then selects) when nothing was chosen; tapping again closes them.
struct MSMonthField: View {
    @Environment(\.locale) private var locale
    @Environment(\.isEnabled) private var isEnabled
    let label: String
    @Binding var selection: YearMonth?
    let years: ClosedRange<Int>
    let opening: YearMonth
    var identifier: String?
    var placeholder: String
    var hint: String?
    var error: String?
    let title: (YearMonth) -> String
    @State private var isOpen = false

    init(
        _ label: String,
        selection: Binding<YearMonth?>,
        years: ClosedRange<Int>,
        opening: YearMonth,
        identifier: String? = nil,
        placeholder: String = "Select month",
        hint: String? = nil,
        error: String? = nil,
        title: @escaping (YearMonth) -> String
    ) {
        self.label = label
        _selection = selection
        self.years = years
        self.opening = opening
        self.identifier = identifier
        self.placeholder = placeholder
        self.hint = hint
        self.error = error
        self.title = title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // VoiceOver gets the label from the field itself.
            Text(label).textStyle(.bodyStrong14).foregroundStyle(Color.ms.ink).accessibilityHidden(true)
            Button(action: toggle) {
                HStack(spacing: Spacing.sm) {
                    Text(selection.map(title) ?? placeholder)
                        .textStyle(.body16)
                        .foregroundStyle(selection == nil ? Color.ms.textSecondary : Color.ms.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    IconView(.chevronDown, size: 16)
                        .foregroundStyle(Color.ms.textSecondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.horizontal, Spacing.md)
                .frame(height: ControlHeight.md)
                .background(
                    isEnabled ? Color.ms.surfacePage : Color.ms.surfaceCard,
                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityValue(selection.map(title) ?? placeholder)
            .accessibilityIdentifier(identifier ?? "")
            if isOpen {
                wheels
            }
            if let error {
                Text(error).textStyle(.caption12).foregroundStyle(Color.ms.danger)
            } else if let hint {
                Text(hint).textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
            }
        }
    }

    /// Month names in the device's language beside four-digit years (never grouped as "2,026").
    private var wheels: some View {
        HStack(spacing: 0) {
            Picker("Month", selection: monthBinding) {
                ForEach(1...12, id: \.self) { month in
                    Text(monthSymbols[month - 1]).tag(month)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityIdentifier("\(identifier ?? "month").month")
            Picker("Year", selection: yearBinding) {
                ForEach(Array(years), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityIdentifier("\(identifier ?? "month").year")
        }
        .pickerStyle(.wheel)
        .transition(.opacity)
    }

    private var shown: YearMonth { selection ?? opening }

    private var monthBinding: Binding<Int> {
        Binding(get: { shown.month }, set: { selection = YearMonth(year: shown.year, month: $0) })
    }

    private var yearBinding: Binding<Int> {
        Binding(get: { shown.year }, set: { selection = YearMonth(year: $0, month: shown.month) })
    }

    private var monthSymbols: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return calendar.monthSymbols
    }

    private var borderColor: Color {
        if error != nil { return .ms.danger }
        if isOpen { return .ms.primary }
        return isEnabled ? .ms.ink : .ms.mute
    }

    private func toggle() {
        if selection == nil { selection = opening }
        withAnimation(.easeOut(duration: Motion.base)) { isOpen.toggle() }
    }
}

#Preview("Month field") {
    @Previewable @State var month: YearMonth?
    VStack(spacing: Spacing.lg) {
        MSMonthField("Expires", selection: $month, years: 2024...2036, opening: YearMonth(year: 2026, month: 10)) {
            "\($0.month)/\($0.year)"
        }
        MSMonthField(
            "Expires", selection: .constant(YearMonth(year: 2026, month: 12)), years: 2024...2036,
            opening: YearMonth(year: 2026, month: 10), error: "Choose a month"
        ) { "\($0.month)/\($0.year)" }
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
