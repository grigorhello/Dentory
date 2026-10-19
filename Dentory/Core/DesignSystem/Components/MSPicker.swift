import SwiftUI

/// Single choice from a short list, drawn like a text field and opening a menu. `nil` shows the placeholder.
/// Pass the Appendix B id as `identifier`: it goes on the menu button, so UI tests can open it.
struct MSPicker<Value: Hashable & Sendable>: View {
    @Environment(\.isEnabled) private var isEnabled
    let label: String?
    @Binding var selection: Value?
    let options: [Value]
    let title: (Value) -> String
    var identifier: String?
    var placeholder = "Select"
    var hint: String?
    var error: String?

    init(
        _ label: String?,
        selection: Binding<Value?>,
        options: [Value],
        identifier: String? = nil,
        placeholder: String = "Select",
        hint: String? = nil,
        error: String? = nil,
        title: @escaping (Value) -> String
    ) {
        self.label = label
        _selection = selection
        self.options = options
        self.identifier = identifier
        self.placeholder = placeholder
        self.hint = hint
        self.error = error
        self.title = title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                // VoiceOver gets the label from the menu itself.
                Text(label).textStyle(.bodyStrong14).foregroundStyle(Color.ms.ink).accessibilityHidden(true)
            }
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(title(option)) { selection = option }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text(selection.map(title) ?? placeholder)
                        .textStyle(.body16)
                        .foregroundStyle(selection == nil ? Color.ms.textSecondary : Color.ms.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    IconView(.chevronDown, size: 16).foregroundStyle(Color.ms.textSecondary)
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
            .accessibilityLabel(label ?? placeholder)
            .accessibilityValue(selection.map(title) ?? "")
            .accessibilityIdentifier(identifier ?? "")
            if let error {
                Text(error).textStyle(.caption12).foregroundStyle(Color.ms.danger)
            } else if let hint {
                Text(hint).textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
            }
        }
    }

    private var borderColor: Color {
        if error != nil { return .ms.danger }
        return isEnabled ? .ms.ink : .ms.mute
    }
}

#Preview("Picker") {
    @Previewable @State var category: String? = "Anesthetic"
    VStack(spacing: Spacing.lg) {
        MSPicker("Category", selection: $category, options: ["Anesthetic", "Endodontics", "PPE"]) { $0 }
        MSPicker(
            "Supplier", selection: .constant(String?.none), options: ["Patterson", "Benco"],
            placeholder: "Choose a supplier", hint: "Optional"
        ) { $0 }
        MSPicker("Unit", selection: .constant(String?.none), options: ["box"], error: "Choose a unit.") { $0 }
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
