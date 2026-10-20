import SwiftUI

/// "Sign out?" (PRD §6.9): what happens next, a danger Sign out and Keep.
struct SignOutSheet: View {
    let viewModel: AccountViewModel

    var body: some View {
        MSSheet("Sign out?", identifier: "signOut") {
            Text(viewModel.signOutMessage)
                .textStyle(.body16)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("signOut.message")
        } primary: {
            VStack(spacing: Spacing.sm) {
                MSButton(
                    "Sign out", variant: .danger, isFullWidth: true, isLoading: viewModel.isSigningOut, action: signOut
                )
                .accessibilityIdentifier("signOut.confirm")
                MSButton("Keep", variant: .text, isFullWidth: true, action: viewModel.keep)
                    .accessibilityIdentifier("signOut.keep")
            }
        }
    }

    private func signOut() {
        Task { await viewModel.signOut() }
    }
}
