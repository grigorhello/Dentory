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
/// A field in a row of two (Lot and Expiry, f24) passes `wheelsOpen` and draws `MSMonthWheels` full width under the
/// row itself. An optional month passes `clearLabel`: once one is chosen, an × in place of the icon clears it.
struct MSMonthField: View {
    @Environment(\.isEnabled) private var isEnabled
    let label: String
    @Binding var selection: YearMonth?
    let years: ClosedRange<Int>
    let opening: YearMonth
    var identifier: String?
    var placeholder: String
    var hint: String?
    var error: String?
    var trailingIcon: Icon
    /// What VoiceOver calls the × that clears the month ("Clear expiry"); nil draws no ×.
    var clearLabel: String?
    /// Whether the caller's wheels are open; nil keeps the wheels under this field.
    var wheelsOpen: Binding<Bool>?
    let title: (YearMonth) -> String
    @State private var isOpenHere = false

    init(
        _ label: String,
        selection: Binding<YearMonth?>,
        years: ClosedRange<Int>,
        opening: YearMonth,
        identifier: String? = nil,
        placeholder: String = "Select month",
        hint: String? = nil,
        error: String? = nil,
        trailingIcon: Icon = .chevronDown,
        clearLabel: String? = nil,
        wheelsOpen: Binding<Bool>? = nil,
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
        self.trailingIcon = trailingIcon
        self.clearLabel = clearLabel
        self.wheelsOpen = wheelsOpen
        self.title = title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // VoiceOver gets the label from the field itself.
            Text(label).textStyle(.bodyStrong14).foregroundStyle(Color.ms.ink).accessibilityHidden(true)
            field
            if isOpen && wheelsOpen == nil {
                MSMonthWheels(selection: $selection, years: years, opening: opening, identifier: identifier)
            }
            if let error {
                Text(error).textStyle(.caption12).foregroundStyle(Color.ms.danger)
            } else if let hint {
                Text(hint).textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
            }
        }
    }

    private var field: some View {
        HStack(spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: Spacing.sm) {
                    Text(selection.map(title) ?? placeholder)
                        .textStyle(.body16)
                        .foregroundStyle(selection == nil ? Color.ms.textSecondary : Color.ms.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if !showsClear {
                        IconView(trailingIcon, size: trailingIcon == .chevronDown ? 16 : 20)
                            .foregroundStyle(trailingIcon == .chevronDown ? Color.ms.textSecondary : Color.ms.ink)
                            .rotationEffect(.degrees(isOpen && trailingIcon == .chevronDown ? 180 : 0))
                    }
                }
                .padding(.leading, Spacing.md)
                .padding(.trailing, showsClear ? 0 : Spacing.md)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityValue(selection.map(title) ?? placeholder)
            .accessibilityIdentifier(identifier ?? "")
            if showsClear, let clearLabel {
                Button(action: clear) {
                    IconView(.x, size: 16)
                        .foregroundStyle(Color.ms.textSecondary)
                        .frame(width: ControlHeight.md, height: ControlHeight.md)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
                .accessibilityIdentifier(identifier.map { "\($0).clear" } ?? "")
            }
        }
        .frame(height: ControlHeight.md)
        .background(isEnabled ? Color.ms.surfacePage : Color.ms.surfaceCard, in: .rect(cornerRadius: Radius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(borderColor, lineWidth: 1)
        }
    }

    private var isOpen: Bool { wheelsOpen?.wrappedValue ?? isOpenHere }
    private var showsClear: Bool { clearLabel != nil && selection != nil }

    private var borderColor: Color {
        if error != nil { return .ms.danger }
        if isOpen { return .ms.primary }
        return isEnabled ? .ms.ink : .ms.mute
    }

    private func toggle() {
        if selection == nil { selection = opening }
        setOpen(!isOpen)
    }

    private func clear() {
        selection = nil
        setOpen(false)
    }

    private func setOpen(_ open: Bool) {
        withAnimation(.easeOut(duration: Motion.base)) {
            if let wheelsOpen {
                wheelsOpen.wrappedValue = open
            } else {
                isOpenHere = open
            }
        }
    }
}

/// The month and year wheels of `MSMonthField`: month names in the device's language beside four-digit years (never
/// grouped as "2,026"), on the chosen month or on `opening` while none is chosen. A field in a row of two shows them
/// full width under the row (f24).
struct MSMonthWheels: View {
    @Environment(\.locale) private var locale
    @Binding var selection: YearMonth?
    let years: ClosedRange<Int>
    let opening: YearMonth
    var identifier: String?

    var body: some View {
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
}

#Preview("Month field") {
    @Previewable @State var month: YearMonth?
    @Previewable @State var expiry: YearMonth?
    @Previewable @State var isExpiryOpen = false
    VStack(alignment: .leading, spacing: Spacing.lg) {
        MSMonthField("Expires", selection: $month, years: 2024...2036, opening: YearMonth(year: 2026, month: 10)) {
            "\($0.month)/\($0.year)"
        }
        MSMonthField(
            "Expires", selection: .constant(YearMonth(year: 2026, month: 12)), years: 2024...2036,
            opening: YearMonth(year: 2026, month: 10), error: "Choose a month"
        ) { "\($0.month)/\($0.year)" }
        HStack(alignment: .top, spacing: Spacing.md) {
            MSTextField("Lot", text: .constant(""), placeholder: "Optional")
            MSMonthField(
                "Expiry", selection: $expiry, years: 2024...2036, opening: YearMonth(year: 2026, month: 10),
                placeholder: "Optional", trailingIcon: .calendar, clearLabel: "Clear expiry",
                wheelsOpen: $isExpiryOpen
            ) { "\($0.month)/\($0.year)" }
        }
        if isExpiryOpen {
            MSMonthWheels(selection: $expiry, years: 2024...2036, opening: YearMonth(year: 2026, month: 10))
        }
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
