import SwiftUI

/// Text input: 44 pt, 6 pt radius, ink hairline; blue when focused, danger with an inline error under it.
/// Set the Appendix B id with `.accessibilityIdentifier` on the component.
struct MSTextField: View {
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool
    let label: String?
    @Binding var text: String
    var placeholder = ""
    var hint: String?
    var error: String?
    var icon: Icon?
    var trailingIcon: Icon?
    var suffix: String?
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?

    init(
        _ label: String?,
        text: Binding<String>,
        placeholder: String = "",
        hint: String? = nil,
        error: String? = nil,
        icon: Icon? = nil,
        trailingIcon: Icon? = nil,
        suffix: String? = nil,
        isSecure: Bool = false,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil
    ) {
        self.label = label
        _text = text
        self.placeholder = placeholder
        self.hint = hint
        self.error = error
        self.icon = icon
        self.trailingIcon = trailingIcon
        self.suffix = suffix
        self.isSecure = isSecure
        self.keyboard = keyboard
        self.contentType = contentType
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
            input
                .textStyle(.body16)
                .foregroundStyle(Color.ms.ink)
                .accessibilityLabel(label ?? placeholder)
                .focused($isFocused)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(contentType == .emailAddress ? .never : .sentences)
            if let suffix {
                Text(suffix).textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
            }
            if let trailingIcon {
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
        MSTextField("Minimum", text: .constant("20"), suffix: "cartridges", keyboard: .numberPad)
        MSTextField("Disabled", text: .constant("Read only")).disabled(true)
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
