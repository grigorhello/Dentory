import SwiftUI

/// Review invoice's reading state (Appendix B `invoice.reading`, PRD §6.5, the prototype's `invoice` screen): the
/// document placeholder breathing, "Reading invoice", "Usually under 20 seconds." and the text link Receive manually
/// instead, in the middle of the page. It stands for the upload too, which the admin need not tell apart.
struct InvoiceReadingView: View {
    let onReceiveManually: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xs) {
            DocumentPlaceholder()
                .padding(.bottom, Spacing.lg)
            Text(InvoiceViewModel.readingTitle)
                .textStyle(.bodyStrong16)
                .foregroundStyle(Color.ms.ink)
                .accessibilityIdentifier("invoice.reading.title")
            Text(InvoiceViewModel.readingCaption)
                .textStyle(.body14)
                .foregroundStyle(Color.ms.textSecondary)
                .accessibilityIdentifier("invoice.reading.caption")
            MSButton(
                InvoiceViewModel.receiveManuallyInstead, variant: .text, size: .small, action: onReceiveManually
            )
            .padding(.top, Spacing.lg)
            .accessibilityIdentifier("invoice.reading")
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical, alignment: .center) { height, _ in height * Self.share }
    }

    /// The part of the page's height the block is centred in: the page's middle, a little above the visual centre the
    /// header and banner push down.
    private static let share: CGFloat = 0.8
}

#Preview("Reading") {
    ScrollView {
        InvoiceReadingView {}
            .padding(Spacing.page)
    }
    .background(Color.ms.canvas)
}
