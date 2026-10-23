import SwiftUI

/// A pushed screen that names the ticket bringing the real one: Review invoice (MS-129, MS-130) and Receive manually
/// (MS-127).
struct ReceiveRoutePlaceholderView: View {
    let route: ReceiveRoute

    var body: some View {
        Text(text)
            .textStyle(.body14)
            .foregroundStyle(Color.ms.textSecondary)
            .accessibilityIdentifier("\(identifier).placeholder")
            .pushedScreen(title: title, identifier: identifier)
    }

    private var title: String {
        switch route {
        case .invoice, .newInvoice: "Review invoice"
        case .manual: "Receive manually"
        }
    }

    private var identifier: String {
        switch route {
        case .invoice, .newInvoice: "invoice"
        case .manual: "manual"
        }
    }

    private var text: String {
        switch route {
        case .invoice, .manual:
            "\(title) arrives with its own ticket."
        case .newInvoice(_, let pageCount):
            "\(pageCount == 1 ? "1 page" : "\(pageCount) pages") ready to read. "
                + "Reading invoices arrives with its own ticket."
        }
    }
}
