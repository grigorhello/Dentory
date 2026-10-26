import SwiftUI

/// Review invoice once read (f23): the banner saying how many lines the reading found; the lines to check, each with
/// its state, arrive with MS-130, and a line stands in for them until then.
struct InvoiceReadView: View {
    let banner: String?

    var body: some View {
        if let banner {
            Notice(banner, identifier: "invoice.banner")
        }
        Text(InvoiceViewModel.reviewPlaceholder)
            .textStyle(.body14)
            .foregroundStyle(Color.ms.textSecondary)
            .accessibilityIdentifier("invoice.placeholder")
    }
}
