import SwiftUI

/// A pushed screen that names the tickets bringing the real one: Review invoice (MS-129, MS-130).
struct ReceiveRoutePlaceholderView: View {
    let route: ReceiveRoute

    var body: some View {
        Text(text)
            .textStyle(.body14)
            .foregroundStyle(Color.ms.textSecondary)
            .accessibilityIdentifier("invoice.placeholder")
            .pushedScreen(title: "Review invoice", identifier: "invoice")
    }

    private var text: String {
        switch route {
        case .newInvoice(_, let pageCount):
            "\(pageCount == 1 ? "1 page" : "\(pageCount) pages") ready to read. "
                + "Reading invoices arrives with its own ticket."
        case .invoice, .manual:
            "Review invoice arrives with its own ticket."
        }
    }
}
