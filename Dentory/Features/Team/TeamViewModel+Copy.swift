import Foundation

/// Team's words (f31, ticket MS-138): rows, the menu and the removal's confirmation.
extension TeamViewModel {
    /// The name; the address for an invitation (f31), or for someone without a name.
    func title(for member: TeamMember) -> String {
        member.isPending || member.fullName.isEmpty ? member.email : member.fullName
    }

    /// The address under a name; "Invited · Oct 1" under an invitation.
    func subtitle(for member: TeamMember) -> String {
        member.isPending ? "Invited\u{00A0}· \(formatters.monthDay(member.invitedAt))" : member.email
    }

    /// "SM", "DK"; "—" for an invitation (f31).
    func initials(for member: TeamMember) -> String {
        guard !member.isPending else { return "—" }
        let initials = PersonName.initials(of: member.fullName)
        return initials.isEmpty ? String(member.email.prefix(1)).uppercased() : initials
    }

    /// "Change role to Staff" for an admin, "Change role to Admin" for Staff.
    func changeRoleTitle(for member: TeamMember) -> String {
        member.role == .admin ? "Change role to Staff" : "Change role to Admin"
    }

    func removeTitle(for member: TeamMember) -> String {
        member.isPending ? "Revoke invitation" : "Remove from clinic"
    }

    func removeQuestion(for member: TeamMember) -> String {
        member.isPending ? "Revoke the invitation to \(member.email)?" : "Remove \(title(for: member))?"
    }

    func removeMessage(for member: TeamMember) -> String {
        member.isPending
            ? "The link in their email stops working."
            : "They lose access right away. Their history stays."
    }

    func removeConfirm(for member: TeamMember) -> String {
        member.isPending ? "Revoke" : "Remove"
    }

    /// `team.member[userId]`; an invitation has no account yet, so its row goes by the invitation's id.
    func identifier(for member: TeamMember) -> String {
        "team.member[\((member.userID ?? member.id).uuidString.lowercased())]"
    }
}
