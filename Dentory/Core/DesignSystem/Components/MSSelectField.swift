import SwiftUI

/// A choice made on a sheet, drawn like a text field (f24's Product): the label above, then in the box the choice, or
/// the placeholder, with a caption line under a choice and the 24 pt chevron in body text f24 draws. Tapping it runs
/// `action`, which opens the sheet. Pass the Appendix B id as `identifier`: it goes on the button, so UI tests can open
/// it.
struct MSSelectField: View {
    @Environment(\.isEnabled) private var isEnabled
    let label: String
    /// The choice; nil shows the placeholder.
    let value: String?
    var caption: String?
    var placeholder: String
    var identifier: String?
    let action: () -> Void

    init(
        _ label: String,
        value: String?,
        caption: String? = nil,
        placeholder: String = "Select",
        identifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.value = value
        self.caption = caption
        self.placeholder = placeholder
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // VoiceOver gets the label from the button itself.
            Text(label).textStyle(.bodyStrong14).foregroundStyle(Color.ms.ink).accessibilityHidden(true)
            Button(action: action) {
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        // The choice and its caption wrap rather than lose their ends (MS-149).
                        Text(value ?? placeholder)
                            .textStyle(.body16)
                            .foregroundStyle(value == nil ? Color.ms.textSecondary : Color.ms.ink)
                        if value != nil, let caption {
                            Text(caption)
                                .textStyle(.caption12)
                                .foregroundStyle(Color.ms.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    IconView(.chevronDown, size: 24).foregroundStyle(Color.ms.textBody)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(minHeight: ControlHeight.md)
                .background(
                    isEnabled ? Color.ms.surfacePage : Color.ms.surfaceCard,
                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(isEnabled ? Color.ms.ink : Color.ms.mute, lineWidth: 1)
                )
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityValue(spokenValue)
            .accessibilityIdentifier(identifier ?? "")
        }
    }

    private var spokenValue: String {
        guard let value else { return placeholder }
        return [value, caption].compactMap { $0 }.joined(separator: ", ")
    }
}

#Preview("Select field") {
    VStack(spacing: Spacing.lg) {
        MSSelectField("Product", value: nil, placeholder: "Choose a product") {}
        MSSelectField(
            "Product", value: "Septocaine 4% 1:100,000", caption: "Anesthetic · 54 cartridges in stock",
            placeholder: "Choose a product"
        ) {}
        MSSelectField("Disabled", value: "Gauze", placeholder: "Choose a product") {}.disabled(true)
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
