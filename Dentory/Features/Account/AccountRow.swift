import SwiftUI

/// A row of Account's groups (f29): the icon, the title, an optional value on the right and the chevron, all in ink,
/// or all in danger for Sign out. Its 24 pt icons set the 53 pt pitch f29 to f32 draw. At the accessibility text sizes
/// the value goes under the title, which would otherwise break mid-word beside it ("Tea / m", MS-149).
struct AccountRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let icon: Icon
    let title: String
    var value: String?
    var isDestructive = false
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                IconView(icon, size: 24)
                AnyLayout.row(stacked: dynamicTypeSize.isAccessibilitySize, stackedSpacing: Spacing.xxs) {
                    Text(title)
                        .textStyle(.body16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let value {
                        Text(value)
                            .textStyle(.body14)
                            .foregroundStyle(Color.ms.textSecondary)
                    }
                }
                IconView(.chevronRight, size: 24)
            }
            .foregroundStyle(isDestructive ? Color.ms.danger : Color.ms.ink)
            .padding(.vertical, Spacing.md + Spacing.xxs)
            .frame(minHeight: ControlHeight.hitTarget)
            if showsDivider {
                ListDivider()
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview("Rows") {
    VStack(spacing: Spacing.lg) {
        ListCard {
            AccountRow(icon: .users, title: "Team", value: "3 people")
            AccountRow(icon: .settings, title: "Clinic settings", showsDivider: false)
        }
        ListCard {
            AccountRow(icon: .lifeBuoy, title: "Help")
            AccountRow(icon: .logOut, title: "Sign out", isDestructive: true, showsDivider: false)
        }
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
