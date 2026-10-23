import SwiftUI

/// One person on the team (f31): initials in a soft circle ("—" for an invitation), name over address (or address
/// over "Invited · Oct 1"), and the role on the right, Admin in the primary blue.
struct TeamMemberRow: View {
    let initials: String
    let title: String
    let subtitle: String
    let role: MembershipRole
    var showsDivider = true
    /// The circle grows with Dynamic Type, so the initials stay inside it.
    @ScaledMetric(relativeTo: .caption) private var avatarSize = ControlHeight.sm

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                Text(initials)
                    .textStyle(.micro12)
                    .foregroundStyle(Color.ms.ink)
                    .lineLimit(1)
                    .frame(width: avatarSize, height: avatarSize)
                    .background(Color.ms.canvasSunken, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title).textStyle(.body16).foregroundStyle(Color.ms.ink)
                    Text(subtitle).textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(role.label)
                    .textStyle(.body16)
                    .foregroundStyle(role == .admin ? Color.ms.primary : Color.ms.textSecondary)
            }
            .padding(.vertical, Spacing.md + Spacing.xxs)
            .frame(minHeight: ControlHeight.hitTarget)
            if showsDivider {
                ListDivider()
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview("Team rows") {
    ListCard {
        TeamMemberRow(initials: "SM", title: "Sarah Mitchell", subtitle: "sarah@smiledental.ca", role: .admin)
        TeamMemberRow(initials: "MR", title: "Michael Reyes", subtitle: "michael@smiledental.ca", role: .staff)
        TeamMemberRow(
            initials: "—", title: "priya@smiledental.ca", subtitle: "Invited · Oct 1", role: .staff, showsDivider: false
        )
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
