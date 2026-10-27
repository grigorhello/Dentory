import PhotosUI
import SwiftUI

/// Admin sign-up in three steps (f2, f3, f4). Pushed from Sign in, or shown at step 2 or 3 when a
/// relaunch finds a user without a clinic or a clinic whose team step is still due.
struct OnboardingView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: OnboardingViewModel
    @State private var logoItem: PhotosPickerItem?
    @FocusState private var focus: OnboardingAccountField?
    /// Step 1's three fields, measured so `OnboardingFieldsReveal` knows whether they fit above the Continue bar.
    @State private var accountFieldsHeight: CGFloat = 0
    let onFinished: () -> Void

    init(viewModel: OnboardingViewModel, onFinished: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinished = onFinished
    }

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    OfflineBannerHost()
                    switch viewModel.step {
                    case .account:
                        OnboardingAccountStep(viewModel: viewModel, focus: $focus, height: $accountFieldsHeight)
                    case .clinic: OnboardingClinicStep(viewModel: viewModel, logoItem: $logoItem)
                    case .invite: OnboardingInviteStep(viewModel: viewModel)
                    }
                }
                .padding(.bottom, Spacing.xl)
                .contentColumn()
            }
            .scrollDismissesKeyboard(.interactively)
            // With the keyboard up the pinned Continue bar sits on it: step 1's fields are scrolled clear of it.
            .modifier(OnboardingFieldsReveal(
                focus: focus, fieldsHeight: accountFieldsHeight, passwordHint: viewModel.passwordHint,
                scroller: scroller
            ))
        }
        .background(Color.ms.canvas)
        .statusBarBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .pinnedPrimaryBar { primaryButton }
        .toastHost()
        .onChange(of: viewModel.generalError) { _, error in
            guard let error else { return }
            dependencies.toasts.show(error.userMessage)
            viewModel.clearGeneralError()
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            guard finished else { return }
            if let message = viewModel.completionMessage {
                dependencies.toasts.show(message)
            }
            onFinished()
        }
        .onChange(of: logoItem) { _, item in
            guard let item else { return }
            Task { viewModel.logoData = try? await item.loadTransferable(type: Data.self) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if viewModel.step == .account {
                // Only step 1 goes back to Sign in; after that the account exists.
                Button {
                    dismiss()
                } label: {
                    IconView(.chevronLeft, size: 24)
                        .foregroundStyle(Color.ms.ink)
                        .frame(width: ControlHeight.md, height: ControlHeight.md)
                        .contentShape(Rectangle())
                }
                .padding(.leading, -Spacing.sm)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("onboard.back")
            }
            Eyebrow("Admin sign-up\(Caption.separator)Step \(viewModel.step.rawValue) of 3")
                .padding(.top, viewModel.step == .account ? 0 : Spacing.xxl)
            OnboardingTitle(lines: titleLines)
            if let caption {
                Text(caption).textStyle(.body16).foregroundStyle(Color.ms.textBody)
            }
        }
        .padding(.top, Spacing.lg)
    }

    /// The title as the frames break it on a phone (f2, f3, f4).
    private var titleLines: [String] {
        switch viewModel.step {
        case .account: ["Create your admin", "account"]
        case .clinic: ["Create your clinic"]
        case .invite: ["Invite your team"]
        }
    }

    private var caption: String? {
        switch viewModel.step {
        case .account: "You will own the clinic workspace and invite the team."
        case .clinic: nil
        case .invite: "Each person gets an email with a link to set their password. You can add more later under Team."
        }
    }

    @ViewBuilder private var primaryButton: some View {
        switch viewModel.step {
        case .account:
            MSButton(
                "Continue →", isFullWidth: true, isLoading: viewModel.isSubmitting,
                isDisabled: !viewModel.canContinueAccount
            ) { Task { await viewModel.createAccount() } }
            .accessibilityIdentifier("onboard.continue")
        case .clinic:
            MSButton(
                "Create clinic →", isFullWidth: true, isLoading: viewModel.isSubmitting,
                isDisabled: !viewModel.canCreateClinic
            ) { Task { await viewModel.createClinic() } }
            .accessibilityIdentifier("onboard.continue")
        case .invite:
            VStack(spacing: Spacing.xs) {
                MSButton(
                    "Send invitations", icon: .send, isFullWidth: true, isLoading: viewModel.isSubmitting,
                    isDisabled: !viewModel.canSendInvites
                ) { Task { await viewModel.sendInvites() } }
                .accessibilityIdentifier("onboard.sendInvites")
                Button("Skip for now") { viewModel.skipInvites() }
                    .buttonStyle(.ms(.text, size: .medium, fullWidth: true))
                    .accessibilityIdentifier("onboard.skip")
            }
        }
    }
}

/// Step 1 · Account (f2). Return moves from the name to the email and the password, as on Sign in and Join, and on the
/// password continues. The placeholder says the password's minimum, as f2 draws it; once 1 to 7 characters are typed
/// the hint under the field says it too, so a disabled Continue has its reason on screen.
private struct OnboardingAccountStep: View {
    @Bindable var viewModel: OnboardingViewModel
    var focus: FocusState<OnboardingAccountField?>.Binding
    /// From Full name's label to the end of the password's hint or error.
    @Binding var height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            MSTextField(
                "Full name", text: $viewModel.fullName, identifier: "onboard.name",
                placeholder: "Dr. Sarah Mitchell", error: viewModel.nameError, contentType: .name
            )
            .focused(focus, equals: .name)
            .submitLabel(.next)
            .onSubmit { focus.wrappedValue = .email }
            .id(OnboardingAccountField.name)
            MSTextField(
                "Work email", text: $viewModel.email, identifier: "onboard.email",
                placeholder: "name@clinic.com", error: viewModel.emailError, keyboard: .emailAddress,
                contentType: .emailAddress
            )
            .focused(focus, equals: .email)
            .submitLabel(.next)
            .onSubmit { focus.wrappedValue = .password }
            .id(OnboardingAccountField.email)
            MSTextField(
                "Password", text: $viewModel.password, identifier: "onboard.password",
                placeholder: NewPassword.requirement, hint: viewModel.passwordHint, error: viewModel.passwordError,
                isSecure: true, contentType: .newPassword
            )
            .focused(focus, equals: .password)
            .submitLabel(.go)
            .onSubmit { Task { await viewModel.createAccount() } }
            .id(OnboardingAccountField.password)
        }
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.height
        } action: { newHeight in
            height = newHeight
        }
    }
}

/// Step 2 · Clinic (f3).
private struct OnboardingClinicStep: View {
    @Bindable var viewModel: OnboardingViewModel
    @Binding var logoItem: PhotosPickerItem?

    var body: some View {
        let logoData = viewModel.logoData
        PhotosPicker(selection: $logoItem, matching: .images) {
            LogoPickerLabel(logoData: logoData)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clinic logo")
        .accessibilityIdentifier("onboard.logo")
        MSTextField(
            "Clinic name", text: $viewModel.clinicName, identifier: "onboard.clinicName",
            placeholder: "Smile Dental", error: viewModel.clinicNameError, contentType: .organizationName
        )
        HStack(alignment: .top, spacing: Spacing.md) {
            MSTextField(
                "City", text: $viewModel.city, identifier: "onboard.city",
                placeholder: "Toronto", error: viewModel.cityError, contentType: .addressCity
            )
            MSPicker("Country", selection: $viewModel.country, options: viewModel.countries, placeholder: "Select") {
                $0.name
            }
            .accessibilityIdentifier("onboard.country")
        }
    }

}

/// Step 3 · Invite team (f4).
private struct OnboardingInviteStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ForEach($viewModel.invites) { $row in
            let index = viewModel.invites.firstIndex { $0.id == row.id } ?? 0
            HStack(alignment: .top, spacing: Spacing.md) {
                MSTextField(
                    "Email", text: $row.email, identifier: "onboard.inviteRow[\(index)].email",
                    placeholder: "name@clinic.com", error: row.error, keyboard: .emailAddress,
                    contentType: .emailAddress
                )
                MSPicker("Role", selection: roleBinding($row.role), options: [MembershipRole.staff, .admin]) {
                    $0.label
                }
                .frame(width: ControlWidth.shortSelect)
                .accessibilityIdentifier("onboard.inviteRow[\(index)].role")
            }
        }
        Button {
            viewModel.addInviteRow()
        } label: {
            HStack(spacing: Spacing.sm) {
                IconView(.plus, size: 16)
                Text("Another person")
            }
        }
        .buttonStyle(.ms(.text, size: .medium, fullWidth: true))
        .accessibilityIdentifier("onboard.addRow")
    }

    private func roleBinding(_ role: Binding<MembershipRole>) -> Binding<MembershipRole?> {
        Binding(get: { role.wrappedValue }, set: { role.wrappedValue = $0 ?? .staff })
    }
}

#Preview("Step 1") {
    NavigationStack {
        OnboardingView(viewModel: AppDependencies.preview(signedIn: false).makeOnboardingViewModel(
            sessionStore: SessionStore(auth: PreviewAuthService(session: nil), state: .signedOut)
        )) {}
    }
}
