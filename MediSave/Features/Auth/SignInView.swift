import SwiftUI

/// Sign in (f1): title, caption, email, password with show/hide, Sign in, Forgot password, footer.
/// No Google button (MS-100 D4).
struct SignInView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: SignInViewModel
    let sessionStore: SessionStore
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
        _viewModel = State(initialValue: SignInViewModel(sessionStore: sessionStore))
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                form(minHeight: proxy.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.ms.canvas)
        .toastHost()
        .onChange(of: viewModel.generalError) { _, error in
            guard let error else { return }
            dependencies.toasts.show(SignInViewModel.toastMessage(for: error))
            viewModel.clearGeneralError()
        }
        .onAppear {
            if sessionStore.accessWasRevoked {
                dependencies.toasts.show(SignInViewModel.toastMessage(for: .forbidden))
                sessionStore.acknowledgeRevokedAccess()
            }
        }
        .accessibilityIdentifier("signin")
    }

    /// The form fills the screen so the footer sits at the bottom (f1) and scrolls when the keyboard is up.
    private func form(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            heading
            OfflineBannerHost()
            emailField
            passwordField
            MSButton(
                "Sign in",
                isFullWidth: true,
                isLoading: viewModel.isSubmitting,
                isDisabled: !viewModel.canSubmit
            ) {
                focus = nil
                Task { await viewModel.signIn() }
            }
            .padding(.top, Spacing.sm)
            .accessibilityIdentifier("signin.submit")
            Button("Forgot password") {
                dependencies.toasts.show("Password reset arrives with a later update.")
            }
            .buttonStyle(.ms(.text, size: .medium, fullWidth: true))
            .accessibilityIdentifier("signin.forgot")
            Spacer(minLength: Spacing.xxxl)
            footer
        }
        .padding(.horizontal, Spacing.page)
        .padding(.bottom, Spacing.xl)
        .frame(maxWidth: PageLayout.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .frame(minHeight: minHeight)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("MediSave")
                .textStyle(.display32)
                .foregroundStyle(Color.ms.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Sign in to your clinic.").textStyle(.body16).foregroundStyle(Color.ms.textSecondary)
        }
        .padding(.top, Spacing.xxxxl)
        .padding(.bottom, Spacing.xl)
    }

    private var emailField: some View {
        MSTextField(
            "Email",
            text: $viewModel.email,
            identifier: "signin.email",
            placeholder: "you@clinic.com",
            error: viewModel.emailError,
            keyboard: .emailAddress,
            contentType: .emailAddress
        )
        .focused($focus, equals: .email)
        .submitLabel(.next)
        .onSubmit { focus = .password }
    }

    private var passwordField: some View {
        MSTextField(
            "Password",
            text: $viewModel.password,
            identifier: "signin.password",
            error: viewModel.passwordError,
            trailingIcon: viewModel.isPasswordShown ? .eyeOff : .eye,
            trailingAction: .init(
                label: viewModel.isPasswordShown ? "Hide password" : "Show password",
                identifier: "signin.password.toggle"
            ) { viewModel.isPasswordShown.toggle() },
            isSecure: !viewModel.isPasswordShown,
            contentType: .password
        )
        .focused($focus, equals: .password)
        .submitLabel(.go)
        .onSubmit { Task { await viewModel.signIn() } }
    }

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text("Setting up a new clinic?").textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
                Button("Sign up as admin") {
                    dependencies.toasts.show("Sign up arrives with a later update.")
                }
                .textStyle(.bodyStrong14)
                .foregroundStyle(Color.ms.primary)
                .accessibilityIdentifier("signin.signUpAdmin")
            }
            Text("Staff join through the invitation email.")
                .textStyle(.body14)
                .foregroundStyle(Color.ms.textSecondary)
                .accessibilityIdentifier("signin.staffNote")
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Sign in") {
    SignInView(sessionStore: SessionStore(auth: PreviewAuthService(session: nil), state: .signedOut))
}
