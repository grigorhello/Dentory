import SwiftUI

/// Reset password (MS-113, gap G4, not drawn; built from the Sign in components): a pushed screen with the
/// caption, the email prefilled from Sign in and Send link. The confirmation is one success notice that reads
/// the same for every address.
struct ResetPasswordView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: ResetPasswordViewModel

    init(viewModel: ResetPasswordViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            MSTextField(
                "Email",
                text: $viewModel.email,
                identifier: "resetPassword.email",
                placeholder: "you@clinic.com",
                error: viewModel.emailError,
                keyboard: .emailAddress,
                contentType: .emailAddress
            )
            .submitLabel(.send)
            .onSubmit { Task { await viewModel.send() } }
            MSButton(
                "Send link", isFullWidth: true, isLoading: viewModel.isSubmitting, isDisabled: !viewModel.canSend
            ) {
                Task { await viewModel.send() }
            }
            .padding(.top, Spacing.sm)
            .accessibilityIdentifier("resetPassword.send")
            if let confirmation = viewModel.confirmation {
                Notice(confirmation, tone: .success)
                    .accessibilityIdentifier("resetPassword.sent")
            }
        }
        .animation(Motion.fastAnimation, value: viewModel.confirmation)
        .pushedScreen(
            title: "Reset password",
            subtitle: "We'll email you a link to set a new password.",
            identifier: "resetPassword"
        )
        .toastHost()
        .onChange(of: viewModel.generalError) { _, error in
            guard let error else { return }
            dependencies.toasts.show(error.userMessage)
            viewModel.clearGeneralError()
        }
    }
}

#Preview("Reset password") {
    let dependencies = AppDependencies.preview(signedIn: false)
    NavigationStack {
        ResetPasswordView(viewModel: dependencies.makeResetPasswordViewModel(email: "sarah@smiledental.ca"))
    }
    .environment(\.appDependencies, dependencies)
}
