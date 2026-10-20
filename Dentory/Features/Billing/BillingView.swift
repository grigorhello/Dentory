import SwiftUI

/// Billing (f34), pushed from Account for an admin: the trial or plan card, the payment method, and the invoices and
/// billing emails. Add or Change opens Stripe in the in-app browser; Billing follows the webhook once it closes.
struct BillingView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: BillingViewModel

    init(session: Session, dependencies: AppDependencies) {
        _viewModel = State(initialValue: dependencies.makeBillingViewModel(session: session))
    }

    var body: some View {
        content
            .pushedScreen(title: "Billing", identifier: "billing")
            .reloadOnReturn { await viewModel.load() }
            .navigationDestination(for: BillingRoute.self) { route in
                BillingRoutePlaceholderView(route: route)
            }
            .fullScreenCover(item: $viewModel.paymentPage) { page in
                SafariView(url: page.url) {
                    Task { await viewModel.paymentPageClosed() }
                }
                .ignoresSafeArea()
            }
            .onChange(of: viewModel.message) { _, message in
                guard let message else { return }
                dependencies.toasts.show(message)
                viewModel.clearMessage()
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
                NavigationLink(value: BillingRoute.emails) {
                    BillingRow(title: "Billing emails", value: viewModel.billingEmailText, showsDivider: false)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("billing.emails")
            }
        }
    }

    /// "Payment method", the card and Add or Change (f34). With large text the card and the button move under the
    /// title.
    private var paymentMethod: some View {
        ListCard {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) {
                    paymentTitle.frame(maxWidth: .infinity, alignment: .leading)
                    cardAndAction
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    paymentTitle
                    HStack(spacing: Spacing.sm) {
                        cardAndAction
                    }
                }
            }
            .padding(.vertical, Spacing.md)
            .frame(minHeight: ControlHeight.hitTarget)
        }
    }

    private var paymentTitle: some View {
        Text("Payment method").textStyle(.body16).foregroundStyle(Color.ms.ink)
    }

    /// The card and the button keep their whole width.
    @ViewBuilder private var cardAndAction: some View {
        if let card = viewModel.cardText {
            Text(card)
                .textStyle(.body14)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize()
                .accessibilityIdentifier("billing.card")
        }
        MSButton(viewModel.paymentActionTitle, variant: .text, size: .small, isLoading: viewModel.isOpeningPayment) {
            Task { await viewModel.managePayment() }
        }
        .fixedSize()
        .accessibilityIdentifier("billing.paymentMethod")
    }
}

#Preview("Billing") {
    NavigationStack {
        BillingView(session: .demo, dependencies: .preview())
    }
}
