import SwiftUI

/// "Invite a teammate" (Appendix C `invite`, the prototype's sheet): Name, Email, Role and Send invitation. The sheet
/// owns its view model, so what is typed survives the screen behind it drawing again.
struct InviteTeammateSheet: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: InviteTeammateViewModel

    init(viewModel: InviteTeammateViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        MSSheet("Invite a teammate", identifier: "invite") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                MSTextField(
                    "Name", text: $viewModel.name, identifier: "invite.name", placeholder: "Full name",
                    contentType: .name
                )
                MSTextField(
                    "Email", text: $viewModel.email, identifier: "invite.email", placeholder: "name@clinic.com",
                    error: viewModel.emailError, keyboard: .emailAddress, contentType: .emailAddress
                )
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Role")
                        .textStyle(.bodyStrong14)
                        .foregroundStyle(Color.ms.ink)
                        .accessibilityAddTraits(.isHeader)
                    SegmentedControl(selection: $viewModel.role, options: viewModel.roleOptions)
                        .accessibilityIdentifier("invite.role")
                }
            }
        } primary: {
            MSButton(
                "Send invitation", isFullWidth: true, isLoading: viewModel.isSending, isDisabled: !viewModel.canSend,
                action: send
            )
            .accessibilityIdentifier("invite.send")
        }
        .onChange(of: viewModel.generalError) { _, error in
            guard let error else { return }
            dependencies.toasts.show(error.userMessage)
            viewModel.clearGeneralError()
        }
    }

    private func send() {
        Task { await viewModel.send() }
    }
}
