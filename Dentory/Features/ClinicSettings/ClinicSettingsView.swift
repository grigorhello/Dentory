import PhotosUI
import SwiftUI

/// Clinic settings (f33, PRD §6.9, MS-100 D14), pushed from Account for an admin: the logo, name, city and country,
/// currency and time zone, then the alerts: the expiry warning and the weekly email digest. Save sits in the header;
/// Back with unsaved changes asks first.
struct ClinicSettingsView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.writeAccess) private var writeAccess
    @State private var viewModel: ClinicSettingsViewModel
    @State private var logoItem: PhotosPickerItem?

    init(session: Session, sessionStore: SessionStore?, dependencies: AppDependencies) {
        _viewModel = State(
            initialValue: dependencies.makeClinicSettingsViewModel(session: session, sessionStore: sessionStore)
        )
    }

    var body: some View {
        content
            .pushedScreen(title: "Clinic settings", identifier: "settings", action: saveAction, onBack: back)
            .task { await viewModel.load() }
            .onChange(of: logoItem) { _, item in
                guard let item else { return }
                Task { viewModel.logoData = try? await item.loadTransferable(type: Data.self) }
            }
            .onChange(of: viewModel.message) { _, message in
                guard let message else { return }
                dependencies.toasts.show(message)
                viewModel.clearMessage()
            }
            .onChange(of: viewModel.generalError) { _, error in
                guard let error else { return }
                dependencies.toasts.show(error.userMessage)
                viewModel.clearGeneralError()
            }
            .msSheet(isPresented: $viewModel.isConfirmingDiscard) {
                DiscardChangesSheet(onDiscard: discard, onKeep: viewModel.keepEditing)
            }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .failed(let error):
            Notice(error.userMessage, tone: .danger)
        case .loading:
            ListCard {
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("settings.loading")
        case .loaded:
            form
        }
    }

    @ViewBuilder private var form: some View {
        // The picker's label closure is Sendable in the iOS 26 SDK: it takes the values, not the view model.
        let logoPreview = viewModel.logoPreview
        let logoHint = viewModel.logoHint
        PhotosPicker(selection: $logoItem, matching: .images) {
            LogoPickerLabel(logoData: logoPreview, hint: logoHint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clinic logo")
        .accessibilityHint(logoHint)
        .accessibilityIdentifier("settings.logo")
        MSTextField(
            "Clinic name", text: $viewModel.name, identifier: "settings.clinicName", placeholder: "Smile Dental",
            error: viewModel.nameError, contentType: .organizationName
        )
        FieldRow {
            MSTextField(
                "City", text: $viewModel.city, identifier: "settings.city", placeholder: "Toronto",
                contentType: .addressCity
            )
            MSPicker(
                "Country", selection: $viewModel.country, options: viewModel.countries, identifier: "settings.country"
            ) { $0.name }
        }
        // A currency is three letters: its select is narrow, so the time zone gets the rest of the row and reads whole
        // ("America/Vancouver" on an iPhone SE, MS-136 audit V-14).
        FieldRow {
            MSPicker(
                "Currency", selection: $viewModel.currency, options: ClinicSettingsViewModel.currencies,
                identifier: "settings.currency"
            ) { $0 }
            .shortSelectWidth()
            MSPicker(
                "Time zone", selection: $viewModel.timeZone, options: viewModel.timeZones,
                identifier: "settings.timeZone"
            ) { $0 }
        }
        Eyebrow("Alerts")
            .accessibilityAddTraits(.isHeader)
            .padding(.top, Spacing.sm)
        MSPicker(
            "Expiry warning", selection: $viewModel.expiryWarning, options: ExpiryWarning.allCases,
            identifier: "settings.expiryWarning"
        ) { $0.label }
        CardView {
            Toggle(isOn: $viewModel.emailDigest) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Email digest")
                    Text("Weekly, Monday 7 am")
                        .textStyle(.body14)
                        .foregroundStyle(Color.ms.textSecondary)
                }
            }
            .toggleStyle(.ms)
            .accessibilityIdentifier("settings.digest")
        }
    }

    /// "Save" in the header (f33), on once something changed.
    private var saveAction: PushedHeader.HeaderAction {
        PushedHeader.HeaderAction(
            title: "Save", identifier: "settings.save", variant: .text, isLoading: viewModel.isSaving,
            isDisabled: !viewModel.canSave
        ) { [writeAccess, viewModel] in
            // In read-only mode the sheet says why instead (MS-142).
            writeAccess.perform { Task { await viewModel.save() } }
        }
    }

    private func back() {
        if viewModel.shouldLeave() { leave() }
    }

    private func discard() {
        viewModel.discard()
        leave()
    }

    private func leave() {
        Task { await viewModel.leave() }
        dismiss()
    }
}

#Preview("Clinic settings") {
    NavigationStack {
        ClinicSettingsView(session: .demo, sessionStore: nil, dependencies: .preview())
    }
}
