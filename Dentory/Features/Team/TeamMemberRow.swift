import SwiftUI

/// One person on the team (f31): initials in a soft circle ("—" for an invitation), name over address (or address
/// over "Invited · Oct 1"), and the role on the right, or under them at a large text size, Admin in the primary blue.
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
                // Where the address and the role do not fit on one line, at a large text size, the role goes under
                // the address rather than break it mid-word (MS-149).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.md) {
                        names.frame(maxWidth: .infinity, alignment: .leading)
                        roleLabel
                    }
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        names
                        roleLabel
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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

    private var names: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).textStyle(.body16).foregroundStyle(Color.ms.ink)
            Text(subtitle).textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
        }
    }

    private var roleLabel: some View {
        Text(role.label)
            .textStyle(.body16)
            .foregroundStyle(role == .admin ? Color.ms.primary : Color.ms.textSecondary)
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
