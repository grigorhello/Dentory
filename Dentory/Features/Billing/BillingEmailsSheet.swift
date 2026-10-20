import SwiftUI

/// "Billing emails" (PRD Appendix C `billingEmails`): the primary address first, without an X; the others with one;
/// a field and Add; Done saves. Open from Billing's Billing emails row.
struct BillingEmailsSheet: View {
    @State private var viewModel: BillingEmailsViewModel
    let onDone: () -> Void

    init(viewModel: BillingEmailsViewModel, onDone: @escaping () -> Void) {
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
        .onChange(of: viewModel.isSaved) { _, isSaved in
            if isSaved { onDone() }
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
                    ListRow(primary, caption: "Primary", showsDivider: !viewModel.extra.isEmpty)
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
            HStack(alignment: .top, spacing: Spacing.sm) {
                MSTextField(
                    nil, text: $viewModel.newEmail, identifier: "billingEmails.email", placeholder: "Add email",
                    error: viewModel.emailError, keyboard: .emailAddress, contentType: .emailAddress
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(viewModel.add)
                MSButton("Add", variant: .tertiary, isDisabled: !viewModel.canAdd, action: viewModel.add)
                    .accessibilityIdentifier("billingEmails.add")
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
