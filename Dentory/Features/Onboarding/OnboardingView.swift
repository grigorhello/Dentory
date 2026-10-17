import PhotosUI
import SwiftUI

/// Admin sign-up in three steps (f2, f3, f4). Pushed from Sign in, or shown at step 2 or 3 when a
/// relaunch finds a user without a clinic or a clinic whose team step is still due.
struct OnboardingView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: OnboardingViewModel
    @State private var logoItem: PhotosPickerItem?
    let onFinished: () -> Void

    init(viewModel: OnboardingViewModel, onFinished: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinished = onFinished
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                OfflineBannerHost()
                switch viewModel.step {
                case .account: OnboardingAccountStep(viewModel: viewModel)
                case .clinic: OnboardingClinicStep(viewModel: viewModel, logoItem: $logoItem)
                case .invite: OnboardingInviteStep(viewModel: viewModel)
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
            Eyebrow("Admin sign-up · Step \(viewModel.step.rawValue) of 3")
                .padding(.top, viewModel.step == .account ? 0 : Spacing.xxl)
            Text(title)
                .textStyle(.display32)
                .foregroundStyle(Color.ms.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("onboard.title")
            if let caption {
                Text(caption).textStyle(.body16).foregroundStyle(Color.ms.textSecondary)
            }
        }
        .padding(.top, Spacing.lg)
    }

    private var title: String {
        switch viewModel.step {
        case .account: "Create your admin account"
        case .clinic: "Create your clinic"
        case .invite: "Invite your team"
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
                    "Send invitations", icon: .userPlus, isFullWidth: true, isLoading: viewModel.isSubmitting,
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

/// Step 1 · Account (f2).
private struct OnboardingAccountStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        MSTextField(
            "Full name", text: $viewModel.fullName, identifier: "onboard.name",
            placeholder: "Dr. Sarah Mitchell", error: viewModel.nameError, contentType: .name
        )
        MSTextField(
            "Work email", text: $viewModel.email, identifier: "onboard.email",
            placeholder: "name@clinic.com", error: viewModel.emailError, keyboard: .emailAddress,
            contentType: .emailAddress
        )
        MSTextField(
            "Password", text: $viewModel.password, identifier: "onboard.password",
            placeholder: "At least 8 characters", hint: "At least 8 characters", error: viewModel.passwordError,
            isSecure: true, contentType: .newPassword
        )
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

/// The 72 pt tap-to-upload placeholder of f3, or the chosen image.
private struct LogoPickerLabel: View {
    let logoData: Data?

    var body: some View {
        HStack(spacing: Spacing.lg) {
            placeholder
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Clinic logo").textStyle(.bodyStrong16).foregroundStyle(Color.ms.ink)
                Text("Tap to upload. Optional, square works best.")
                    .textStyle(.body14)
                    .foregroundStyle(Color.ms.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: Spacing.xs) {
            if let data = logoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                IconView(.camera, size: 24).foregroundStyle(Color.ms.textSecondary)
                Text("Logo").textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
            }
        }
        .frame(width: 72, height: 72)
        .background(Color.ms.surfaceCard, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .strokeBorder(Color.ms.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
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
                    $0 == .admin ? "Admin" : "Staff"
                }
                .frame(width: 140)
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
