import SwiftUI

/// "Billing emails" (PRD Appendix C `billingEmails`): the first address, labelled Admin, without an X; the others with
/// one; "Add email" and Add; Done saves. Open from Billing's Billing emails row; `onDone` says whether Done saved.
struct BillingEmailsSheet: View {
    @State private var viewModel: BillingEmailsViewModel
    let onDone: (_ saved: Bool) -> Void

    init(viewModel: BillingEmailsViewModel, onDone: @escaping (_ saved: Bool) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onDone = onDone
    }

    var body: some View {
        MSSheet(
            "Billing emails", caption: "Invoices and receipts go to every address here.", identifier: "billingEmails"
        ) {
            content
        } primary: {
            MSButton("Done", isFullWidth: true, isLoading: viewModel.isSaving, action: save)
                .accessibilityIdentifier("billingEmails.done")
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.outcome) { _, outcome in
            if let outcome { onDone(outcome == .saved) }
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            ListCard { SkeletonRow(showsDivider: false) }
        case .failed(let error):
            Notice(error.userMessage, tone: .danger)
        case .loaded:
            ListCard {
                if let primary = viewModel.primary {
                    ListRow(primary, caption: "Admin", showsDivider: !viewModel.extra.isEmpty)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("billingEmails.primary")
                }
                ForEach(viewModel.extra, id: \.self) { email in
                    ListRow(email, showsDivider: email != viewModel.extra.last) {
                        IconButton(.x, label: "Remove \(email)") { viewModel.remove(email) }
                            .accessibilityIdentifier("billingEmails.remove[\(email)]")
                    }
                }
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // The field reads its label to VoiceOver itself; the Add button stays level with the field, or under
                // it at the large text sizes.
                Text("Add email").textStyle(.bodyStrong14).foregroundStyle(Color.ms.ink).accessibilityHidden(true)
                FieldRow(spacing: Spacing.sm) {
                    MSTextField(
                        nil, text: $viewModel.newEmail, identifier: "billingEmails.email",
                        placeholder: "accounting@clinic.com", error: viewModel.emailError, keyboard: .emailAddress,
                        contentType: .emailAddress, accessibilityText: "Add email"
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(viewModel.add)
                    MSButton("Add", variant: .tertiary, isDisabled: !viewModel.canAdd, action: viewModel.add)
                        .accessibilityIdentifier("billingEmails.add")
                }
            }
            if let error = viewModel.generalError {
                Notice(error.userMessage, tone: .danger)
                    .accessibilityIdentifier("billingEmails.error")
            }
        }
    }

    private func save() {
        Task { await viewModel.save() }
    }
}
