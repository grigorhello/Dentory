import SwiftUI

/// Billing (f34, MS-100 D18), pushed from Account for an admin: the trial or plan card, the payment method's status,
/// and the invoices and billing emails. The app links to no payment page; a card added from the emailed link shows
/// here on the next return to the app or pull to refresh.
struct BillingView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: BillingViewModel
    @State private var showsEmails = false
    private let session: Session

    init(session: Session, dependencies: AppDependencies) {
        self.session = session
        _viewModel = State(initialValue: dependencies.makeBillingViewModel(session: session))
    }

    var body: some View {
        content
            .pushedScreen(title: "Billing", identifier: "billing")
            .reloadOnReturn { await viewModel.load() }
            .navigationDestination(for: BillingRoute.self) { route in
                switch route {
                case .invoices:
                    InvoicesView(
                        session: session, trialEndsAt: viewModel.summary?.trialEndsAt, dependencies: dependencies
                    )
                }
            }
            .msSheet(isPresented: $showsEmails) {
                BillingEmailsSheet(
                    viewModel: dependencies.makeBillingEmailsViewModel(session: session) { await viewModel.load() }
                ) {
                    showsEmails = false
                    dependencies.toasts.show(BillingEmailsViewModel.savedMessage)
                }
            }
    }

    @ViewBuilder private var content: some View {
        if case .failed(let error) = viewModel.state {
            Notice(error.userMessage, tone: .danger)
        } else if viewModel.summary == nil {
            ListCard {
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            .accessibilityIdentifier("billing.loading")
        } else {
            BillingPlanCard(viewModel: viewModel)
            paymentMethod
            ListCard {
                NavigationLink(value: BillingRoute.invoices) {
                    BillingRow(title: "Invoices", value: viewModel.invoicesText)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("billing.invoices")
                Button { showsEmails = true } label: {
                    BillingRow(title: "Billing emails", value: viewModel.billingEmailText, showsDivider: false)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("billing.emails")
            }
        }
    }

    /// "Payment method" and its status, the card or "Not set" (f34, MS-100 D18), and without a card where the link to
    /// add one goes.
    private var paymentMethod: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ListCard {
                BillingRow(
                    title: "Payment method", value: viewModel.paymentMethodText, navigates: false, showsDivider: false
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("billing.paymentMethod")
            }
            if let note = viewModel.paymentMethodNote {
                Text(note)
                    .textStyle(.body14)
                    .foregroundStyle(Color.ms.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("billing.paymentMethod.note")
            }
        }
    }
}

#Preview("Billing") {
    NavigationStack {
        BillingView(session: .demo, dependencies: .preview())
    }
}
