import SwiftUI

/// A value shown where a field would be, but not editable: the same 44 pt box and ink hairline as
/// `MSTextField`, on the cream-soft surface (f5, the invited address on the Join screen). It is text, not
/// a disabled text field, so VoiceOver reads it as a value and iOS does not take it for a sign-up form's
/// username field, which would make it cover the password field with an automatic strong password.
struct MSReadOnlyField: View {
    let label: String
    let value: String
    var identifier: String?

    init(_ label: String, value: String, identifier: String? = nil) {
        self.label = label
        self.value = value
        self.identifier = identifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).textStyle(.bodyStrong14).foregroundStyle(Color.ms.ink)
            // A long address wraps rather than lose its middle, and the box grows with it (MS-149).
            Text(value)
                .textStyle(.body16)
                .foregroundStyle(Color.ms.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(minHeight: ControlHeight.md)
                .background(Color.ms.surfaceCard, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(Color.ms.ink, lineWidth: 1)
                )
                .accessibilityIdentifier(identifier ?? "")
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Read-only field") {
    MSReadOnlyField("Email", value: "priya@smiledental.ca")
        .padding(Spacing.page)
        .background(Color.ms.canvas)
}
