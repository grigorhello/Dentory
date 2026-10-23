import SwiftUI

/// Set a new password (MS-113, gap G4, not drawn), opened by the reset email's link: the new password with
/// show/hide and Save password, in the Sign in style. An expired or used link offers a new one; Sign in
/// leaves the link.
struct SetPasswordView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: SetPasswordViewModel
    /// The password is saved and the session reloaded: the root drops the link and shows Home.
    let onFinished: () -> Void
    /// The way out of a link that does not work.
    let onSignIn: () -> Void

    init(viewModel: SetPasswordViewModel, onFinished: @escaping () -> Void, onSignIn: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinished = onFinished
        self.onSignIn = onSignIn
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                OfflineBannerHost()
                content
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, Spacing.xl)
            .frame(maxWidth: PageLayout.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ms.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .toastHost()
        .task { await viewModel.verifyIfNeeded() }
        .onChange(of: viewModel.generalError) { _, error in
            guard let error else { return }
            dependencies.toasts.show(error.userMessage)
            viewModel.clearGeneralError()
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { onFinished() }
        }
        .accessibilityIdentifier("setPassword")
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .verifying:
            ProgressView()
                .tint(Color.ms.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xxxxl)
                .accessibilityIdentifier("setPassword.loading")
        case .ready:
            SetPasswordHeader(title: "Set a new password", caption: "Choose a password for your Dentory account.")
            SetPasswordFields(viewModel: viewModel)
        case .expired:
            SetPasswordHeader(title: "This link has expired", caption: "Send a new one.")
                .accessibilityIdentifier("setPassword.expired")
            NavigationLink(value: PasswordResetRoute(email: "")) {
                Text("Send a new link")
            }
            .buttonStyle(.ms(.primary, size: .medium, fullWidth: true))
            .accessibilityIdentifier("setPassword.sendNew")
            signInButton
        case .failed(let error):
            SetPasswordHeader(title: "Couldn't open the link", caption: error.userMessage)
            MSButton("Try again", variant: .secondary, isFullWidth: true) {
                Task { await viewModel.verify() }
            }
            .accessibilityIdentifier("setPassword.retry")
            signInButton
        }
    }

    private var signInButton: some View {
        Button("Sign in") { onSignIn() }
            .buttonStyle(.ms(.text, size: .medium, fullWidth: true))
            .accessibilityIdentifier("setPassword.signIn")
    }
}

/// Eyebrow "Password reset", the title and the sentence under it, as on the Join screen.
private struct SetPasswordHeader: View {
    let title: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Eyebrow("Password reset")
            Text(title)
                .textStyle(.display32)
                .foregroundStyle(Color.ms.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("setPassword.title")
            Text(caption)
                .textStyle(.body16)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Spacing.xxxxl)
        .padding(.bottom, Spacing.sm)
    }
}

/// The new password with show/hide, then Save password; Return saves.
private struct SetPasswordFields: View {
    @Bindable var viewModel: SetPasswordViewModel

    var body: some View {
        MSTextField(
            "New password",
            text: $viewModel.password,
            identifier: "setPassword.password",
            placeholder: "At least 8 characters",
            error: viewModel.passwordError,
            trailingIcon: viewModel.isPasswordShown ? .eyeOff : .eye,
            trailingAction: .init(
                label: viewModel.isPasswordShown ? "Hide password" : "Show password",
                identifier: "setPassword.password.toggle"
            ) { viewModel.isPasswordShown.toggle() },
            isSecure: !viewModel.isPasswordShown,
            contentType: .newPassword
        )
        .submitLabel(.done)
        .onSubmit { Task { await viewModel.save() } }
        MSButton(
            "Save password", isFullWidth: true, isLoading: viewModel.isSubmitting, isDisabled: !viewModel.canSave
        ) {
            Task { await viewModel.save() }
        }
        .padding(.top, Spacing.sm)
        .accessibilityIdentifier("setPassword.save")
    }
}

#Preview("Set a new password") {
    let dependencies = AppDependencies.preview(signedIn: false)
    NavigationStack {
        SetPasswordView(
            viewModel: dependencies.makeSetPasswordViewModel(
                tokenHash: PreviewAuthService.demoResetToken,
                sessionStore: SessionStore(auth: dependencies.auth, state: .signedOut)
            ),
            onFinished: {},
            onSignIn: {}
        )
    }
    .environment(\.appDependencies, dependencies)
}

#Preview("Expired link") {
    let dependencies = AppDependencies.preview(signedIn: false)
    NavigationStack {
        SetPasswordView(
            viewModel: dependencies.makeSetPasswordViewModel(
                tokenHash: "old-link",
                sessionStore: SessionStore(auth: dependencies.auth, state: .signedOut)
            ),
            onFinished: {},
            onSignIn: {}
        )
    }
    .environment(\.appDependencies, dependencies)
}
