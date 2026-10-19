import SwiftUI

/// Accept invitation (f5): eyebrow, "Join {Clinic}", who invited and as what, the name, the invited address
/// read-only, a new password and the pinned "Join clinic". Opened by the invitation link.
struct AcceptInvitationView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: AcceptInvitationViewModel
    /// Home is next: the root drops the invitation and shows the tabs of the new session.
    let onFinished: () -> Void
    /// The expired state's way out.
    let onSignIn: () -> Void

    init(viewModel: AcceptInvitationViewModel, onFinished: @escaping () -> Void, onSignIn: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinished = onFinished
        self.onSignIn = onSignIn
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                OfflineBannerHost()
                switch viewModel.state {
                case .loading:
                    ProgressView()
                        .tint(Color.ms.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Spacing.xxxxl)
                        .accessibilityIdentifier("invite.loading")
                case .loaded(let invitation):
                    InvitationHeader(title: "Join \(invitation.clinicName)", caption: viewModel.caption)
                        .accessibilityIdentifier("invite.clinic")
                    InvitationFields(viewModel: viewModel, invitation: invitation)
                case .expired:
                    InvitationHeader(title: "This invitation has expired", caption: "Ask your admin to resend.")
                    Button("Sign in") { onSignIn() }
                        .buttonStyle(.ms(.text, size: .medium, fullWidth: true))
                        .accessibilityIdentifier("invite.signIn")
                case .failed(let error):
                    InvitationHeader(title: "Couldn't open the invitation", caption: error.userMessage)
                    MSButton("Try again", variant: .secondary, isFullWidth: true) {
                        Task { await viewModel.load() }
                    }
                    .accessibilityIdentifier("invite.retry")
                }
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, Spacing.xl)
            .frame(maxWidth: PageLayout.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ms.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.invitation != nil {
                PinnedPrimaryBar { joinButton }
            }
        }
        .toastHost()
        .task { await viewModel.load() }
        .onChange(of: viewModel.generalError) { _, error in
            guard let error else { return }
            dependencies.toasts.show(error.userMessage)
            viewModel.clearGeneralError()
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { onFinished() }
        }
    }

    private var joinButton: some View {
        MSButton(
            "Join clinic", isFullWidth: true, isLoading: viewModel.isSubmitting, isDisabled: !viewModel.canJoin
        ) { Task { await viewModel.join() } }
        .accessibilityIdentifier("invite.submit")
    }
}

/// Eyebrow "Invitation", the title and the sentence under it.
private struct InvitationHeader: View {
    let title: String
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Eyebrow("Invitation")
            Text(title)
                .textStyle(.display32)
                .foregroundStyle(Color.ms.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let caption {
                Text(caption)
                    .textStyle(.body16)
                    .foregroundStyle(Color.ms.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, Spacing.xxxxl)
    }
}

/// Name, the invited address (read-only) and the new password. Return on the name moves to the
/// password, as on Sign in; Return on the password joins.
private struct InvitationFields: View {
    @Bindable var viewModel: AcceptInvitationViewModel
    let invitation: Invitation
    @FocusState private var focus: Field?

    private enum Field { case name, password }

    var body: some View {
        MSTextField(
            "Full name", text: $viewModel.fullName, identifier: "invite.name",
            placeholder: "Your name", error: viewModel.nameError, contentType: .name
        )
        .focused($focus, equals: .name)
        .submitLabel(.next)
        .onSubmit { focus = .password }
        MSTextField(
            "Email", text: .constant(invitation.email), identifier: "invite.email",
            keyboard: .emailAddress, contentType: .emailAddress
        )
        .disabled(true)
        // `.password`, not `.newPassword`: on iOS 18.4 the new-password type swaps the keyboard for the
        // system's strong-password suggestion as soon as the field is focused, and nothing can be typed.
        MSTextField(
            "Password", text: $viewModel.password, identifier: "invite.password",
            placeholder: "At least 8 characters", error: viewModel.passwordError,
            isSecure: true, contentType: .password
        )
        .focused($focus, equals: .password)
        .submitLabel(.go)
        .onSubmit { Task { await viewModel.join() } }
    }
}

#Preview("Join") {
    let dependencies = AppDependencies.preview(signedIn: false)
    NavigationStack {
        AcceptInvitationView(
            viewModel: dependencies.makeAcceptInvitationViewModel(
                token: DemoInvitationRepository.validToken,
                sessionStore: SessionStore(auth: PreviewAuthService(session: nil), state: .signedOut)
            ),
            onFinished: {},
            onSignIn: {}
        )
    }
    .environment(\.appDependencies, dependencies)
}

#Preview("Expired") {
    let dependencies = AppDependencies.preview(signedIn: false)
    NavigationStack {
        AcceptInvitationView(
            viewModel: dependencies.makeAcceptInvitationViewModel(
                token: "expired",
                sessionStore: SessionStore(auth: PreviewAuthService(session: nil), state: .signedOut)
            ),
            onFinished: {},
            onSignIn: {}
        )
    }
    .environment(\.appDependencies, dependencies)
}
