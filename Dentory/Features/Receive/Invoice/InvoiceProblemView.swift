import SwiftUI

/// What went wrong on Review invoice as a danger notice ("We couldn't read this invoice. Try a clearer photo or
/// receive manually."), with Try again and, where the delivery can be received by hand, Receive manually beside it.
/// `identifier` names the case: `invoice.failed`, `invoice.upload` or `invoice.load`.
struct InvoiceProblemView: View {
    let text: String
    let identifier: String
    let onTryAgain: () -> Void
    var onReceiveManually: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Notice(text, tone: .danger, identifier: "\(identifier).notice")
            ViewThatFits(in: .horizontal) {
                EqualWidthHStack(spacing: Spacing.md) { buttons }
                VStack(spacing: Spacing.md) { buttons }
            }
        }
    }

    @ViewBuilder private var buttons: some View {
        MSButton(InvoiceViewModel.tryAgain, isFullWidth: true, action: onTryAgain)
            .accessibilityIdentifier("\(identifier).retry")
        if let onReceiveManually {
            MSButton(InvoiceViewModel.receiveManually, variant: .tertiary, isFullWidth: true, action: onReceiveManually)
                .accessibilityIdentifier("\(identifier).manual")
        }
    }
}

#Preview("Problems") {
    VStack(spacing: Spacing.xl) {
        InvoiceProblemView(
            text: InvoiceViewModel.readingFailure, identifier: "invoice.failed", onTryAgain: {}, onReceiveManually: {}
        )
        InvoiceProblemView(text: InvoiceViewModel.loadFailure, identifier: "invoice.load", onTryAgain: {})
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
