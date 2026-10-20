import SwiftUI

/// Invoices and Billing emails until MS-141 brings them.
struct BillingRoutePlaceholderView: View {
    let route: BillingRoute

    var body: some View {
        Text("\(title) arrives with its own ticket.")
            .textStyle(.body14)
            .foregroundStyle(Color.ms.textSecondary)
            .pushedScreen(title: title, identifier: identifier)
    }

    private var title: String {
        switch route {
        case .invoices: "Invoices"
        case .emails: "Billing emails"
        }
    }

    /// The PRD Appendix B screen keys.
    private var identifier: String {
        switch route {
        case .invoices: "invoices"
        case .emails: "billingEmails"
        }
    }
}
