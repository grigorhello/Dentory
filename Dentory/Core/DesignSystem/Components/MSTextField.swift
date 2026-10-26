import SwiftUI

/// Text input: 44 pt, 6 pt radius, ink hairline; blue when focused, danger with an inline error under it.
/// Pass the Appendix B id as `identifier`: it goes on the input itself, so UI tests can tap and type into it.
struct MSTextField: View {
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool
    let label: String?
    @Binding var text: String
    /// The Appendix B id of the input (`signin.email`); the toggle gets `<id>.toggle`.
    var identifier: String?
    var placeholder = ""
    var hint: String?
    var error: String?
    var icon: Icon?
    var trailingIcon: Icon?
    /// Makes the trailing icon a button with this label (the password show/hide toggle).
    var trailingAction: TrailingAction?
    /// Before the input, as a money field shows its currency ("$ 49.80", f24).
    var prefix: String?
    var suffix: String?
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    /// What VoiceOver calls a field whose label is drawn outside it (Billing emails' "Add email"); else the label, else
    /// the placeholder.
    var accessibilityText: String?

    init(
        _ label: String?,
        text: Binding<String>,
        identifier: String? = nil,
        placeholder: String = "",
        hint: String? = nil,
        error: String? = nil,
        icon: Icon? = nil,
        trailingIcon: Icon? = nil,
        trailingAction: TrailingAction? = nil,
        prefix: String? = nil,
        suffix: String? = nil,
        isSecure: Bool = false,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        accessibilityText: String? = nil
    ) {
        self.label = label
        _text = text
        self.identifier = identifier
        self.placeholder = placeholder
        self.hint = hint
        self.error = error
        self.icon = icon
        self.trailingIcon = trailingIcon
        self.trailingAction = trailingAction
        self.prefix = prefix
        self.suffix = suffix
        self.isSecure = isSecure
        self.keyboard = keyboard
        self.contentType = contentType
        self.accessibilityText = accessibilityText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                // VoiceOver gets the label from the field itself.
                Text(label).textStyle(.bodyStrong14).foregroundStyle(Color.ms.ink).accessibilityHidden(true)
            }
            field
            if let error {
                Text(error).textStyle(.caption12).foregroundStyle(Color.ms.danger)
            } else if let hint {
                Text(hint).textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
            }
        }
        .animation(Motion.fastAnimation, value: isFocused)
    }

    private var field: some View {
        HStack(spacing: Spacing.sm) {
            if let icon {
                IconView(icon, size: 16).foregroundStyle(Color.ms.textSecondary)
            }
            if let prefix {
                Text(prefix).textStyle(.body16).foregroundStyle(Color.ms.textSecondary).accessibilityHidden(true)
            }
            input
                .textStyle(.body16)
                .foregroundStyle(Color.ms.ink)
                .accessibilityLabel(accessibilityText ?? label ?? placeholder)
                .accessibilityIdentifier(identifier ?? "")
                .focused($isFocused)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(contentType == .emailAddress ? .never : .sentences)
            if let suffix {
                // The unit keeps its width and one line ("cartridges" in Add expiry's How many on an iPhone SE); the
                // input gives way instead (MS-136 audit V-17).
                Text(suffix)
                    .textStyle(.body14)
                    .foregroundStyle(Color.ms.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            if let trailingIcon, let trailingAction {
                Button(action: trailingAction.perform) {
                    IconView(trailingIcon, size: 20)
                        .foregroundStyle(Color.ms.ink)
                        .frame(width: ControlHeight.md, height: ControlHeight.md)
                        .contentShape(Rectangle())
                }
                .padding(.trailing, -Spacing.md)
                .accessibilityLabel(trailingAction.label)
                .accessibilityIdentifier(identifier.map { "\($0).toggle" } ?? trailingAction.identifier)
            } else if let trailingIcon {
                IconView(trailingIcon, size: 20).foregroundStyle(Color.ms.ink)
            }
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
        .msFocusRing(isFocused)
    }

    @ViewBuilder private var input: some View {
        if isSecure {
            SecureField(placeholder, text: $text, prompt: prompt)
        } else {
            TextField(placeholder, text: $text, prompt: prompt)
        }
    }

    /// A tappable trailing icon: its VoiceOver label, Appendix B id and action.
    struct TrailingAction {
        let label: String
        let identifier: String
        let perform: () -> Void
    }

    private var prompt: Text {
        Text(placeholder).foregroundStyle(Color.ms.textSecondary)
    }

    private var borderColor: Color {
        if error != nil { return .ms.danger }
        if isFocused { return .ms.primary }
        return isEnabled ? .ms.ink : .ms.mute
    }
}

#Preview("Text fields") {
    @Previewable @State var text = "Septocaine 4%"
    VStack(spacing: Spacing.lg) {
        MSTextField("Name", text: $text, hint: "Shown in lists and procedures.")
        MSTextField("Email", text: .constant(""), placeholder: "you@clinic.com", error: "No account with this email.")
        MSTextField("Search", text: .constant(""), placeholder: "Search products", icon: .search)
        MSTextField("Expiry", text: .constant(""), placeholder: "- - - - - -", trailingIcon: .calendar)
        MSTextField(
            "Password", text: .constant("smiledental"),
            trailingIcon: .eye, trailingAction: .init(label: "Show password", identifier: "preview.show") {},
            isSecure: true
        )
        MSTextField("Minimum", text: .constant("20"), suffix: "cartridges", keyboard: .numberPad)
        MSTextField("Cost per box", text: .constant(""), placeholder: "0.00", prefix: "$", keyboard: .decimalPad)
        MSTextField("Disabled", text: .constant("Read only")).disabled(true)
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
