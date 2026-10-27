import SwiftUI

/// Who is signed in (f29, f30): the initials in an ink circle, the name and "Admin · Smile Dental". At the
/// accessibility text sizes the name goes under the circle, which grows with the text, so it keeps its words whole
/// ("Mitche / ll" beside it, MS-149).
struct AccountUserCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let initials: String
    let name: String
    let roleLine: String
    /// The circle grows with Dynamic Type, so the initials stay inside it.
    @ScaledMetric(relativeTo: .subheadline) private var avatarSize = ControlHeight.md

    var body: some View {
        let layout = AnyLayout.row(stacked: dynamicTypeSize.isAccessibilitySize)
        CardView {
            layout {
                Text(initials)
                    .textStyle(.bodyStrong14)
                    .foregroundStyle(Color.ms.textOnDark)
                    .lineLimit(1)
                    .frame(width: avatarSize, height: avatarSize)
                    .background(Color.ms.surfaceDark, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(name).textStyle(.bodyStrong16).foregroundStyle(Color.ms.ink)
                    Text(roleLine).textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("more.user")
    }
}

#Preview("User card") {
    AccountUserCard(initials: "SM", name: "Sarah Mitchell", roleLine: "Admin · Smile Dental")
        .padding(Spacing.page)
        .background(Color.ms.canvas)
}
