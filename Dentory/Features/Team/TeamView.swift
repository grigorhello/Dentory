import SwiftUI

/// Team (f31 Admin, f32 Staff), pushed from Account: everyone on the clinic in one card. An admin invites from the
/// header and opens a person's menu from their row: change the role, resend an invitation, or remove after a
/// confirmation. Staff read the list only.
struct TeamView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.writeAccess) private var writeAccess
    @State private var viewModel: TeamViewModel

    init(session: Session, sessionStore: SessionStore?, dependencies: AppDependencies) {
        _viewModel = State(
            initialValue: dependencies.makeTeamViewModel(session: session, sessionStore: sessionStore)
        )
    }

    var body: some View {
        content
            .pushedScreen(title: "Team", identifier: "team", action: inviteAction)
            .reloadOnReturn { await viewModel.load() }
            .onChange(of: viewModel.message) { _, message in
                guard let message else { return }
                dependencies.toasts.show(message.title, detail: message.detail)
                viewModel.clearMessage()
            }
            .msSheet(item: $viewModel.sheet) { sheet in
                switch sheet {
                case .invite:
                    InviteTeammateSheet(viewModel: dependencies.makeInviteTeammateViewModel(
                        clinicID: viewModel.clinicID, onSent: viewModel.didInvite
                    ))
                case .remove(let member):
                    RemoveMemberSheet(viewModel: viewModel, member: member)
                }
            }
    }

    @ViewBuilder private var content: some View {
        if case .failed(let error) = viewModel.state {
            Notice(error.userMessage, tone: .danger)
        } else if viewModel.members.isEmpty {
            ListCard {
                SkeletonRow()
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("team.loading")
        } else {
            ListCard {
                ForEach(viewModel.members) { member in
                    row(member)
                }
            }
        }
    }

    @ViewBuilder private func row(_ member: TeamMember) -> some View {
        let row = TeamMemberRow(
            initials: viewModel.initials(for: member), title: viewModel.title(for: member),
            subtitle: viewModel.subtitle(for: member), role: member.role,
            showsDivider: member.id != viewModel.members.last?.id
        )
        if viewModel.isAdmin {
            Button {
                viewModel.openMenu(for: member)
            } label: {
                row
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the choices for this person")
            .accessibilityIdentifier(viewModel.identifier(for: member))
            // On the row, so that an iPad's popover points at it; attached to the screen it had nothing to point at
            // and never showed (MS-148). A phone shows the same action sheet as before.
            .confirmationDialog(
                viewModel.title(for: member), isPresented: $viewModel[menuOpenFor: member.id], titleVisibility: .visible
            ) {
                menu(for: member)
            }
        } else {
            row.accessibilityIdentifier(viewModel.identifier(for: member))
        }
    }

    /// `team.member[userId].menu`: its choices go by `.role`, `.resend` and `.remove` under that id. A read-only clinic
    /// keeps Remove, since taking away access must not wait for billing; a new role and a resent invitation wait for a
    /// payment method (the read-only sheet).
    @ViewBuilder private func menu(for member: TeamMember) -> some View {
        let menu = "\(viewModel.identifier(for: member)).menu"
        Button(viewModel.changeRoleTitle(for: member)) {
            writeAccess.perform { Task { await viewModel.changeRole(of: member) } }
        }
        .accessibilityIdentifier("\(menu).role")
        if member.isPending {
            Button("Resend invitation") {
                writeAccess.perform { Task { await viewModel.resend(member) } }
            }
            .accessibilityIdentifier("\(menu).resend")
        }
        Button(viewModel.removeTitle(for: member), role: .destructive) {
            viewModel.askToRemove(member)
        }
        .accessibilityIdentifier("\(menu).remove")
        Button("Cancel", role: .cancel) {}
    }

    /// "Invite" in the header for an admin (f31); nothing for Staff (f32). In read-only mode (MS-142) Invite, Change
    /// role and Resend open the read-only sheet instead, while Remove and Revoke stay open (decisions log, 14:30).
    private var inviteAction: PushedHeader.HeaderAction? {
        guard viewModel.isAdmin else { return nil }
        return PushedHeader.HeaderAction(
            title: "Invite", identifier: "team.invite", variant: .primary, icon: .userPlus,
            perform: { [writeAccess, viewModel] in writeAccess.perform(viewModel.askToInvite) }
        )
    }
}

#Preview("Team · Admin") {
    NavigationStack {
        TeamView(session: .demo, sessionStore: nil, dependencies: .preview())
    }
}
