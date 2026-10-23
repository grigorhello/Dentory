import SwiftUI

/// "Remove Michael Reyes?" or "Revoke the invitation to priya@smiledental.ca?": what happens, a danger Remove or
/// Revoke, and Keep.
struct RemoveMemberSheet: View {
    let viewModel: TeamViewModel
    let member: TeamMember

    var body: some View {
        MSSheet(viewModel.removeQuestion(for: member), identifier: "team.remove") {
            Text(viewModel.removeMessage(for: member))
                .textStyle(.body16)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("team.remove.message")
        } primary: {
            VStack(spacing: Spacing.sm) {
                MSButton(
                    viewModel.removeConfirm(for: member), variant: .danger, isFullWidth: true,
                    isLoading: viewModel.isRemoving, action: remove
                )
                .accessibilityIdentifier("team.remove.confirm")
                MSButton("Keep", variant: .text, isFullWidth: true, action: viewModel.keep)
                    .accessibilityIdentifier("team.remove.keep")
            }
        }
    }

    private func remove() {
        Task { await viewModel.remove(member) }
    }
}
