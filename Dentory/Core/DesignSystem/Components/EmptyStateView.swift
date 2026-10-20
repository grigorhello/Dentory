import SwiftUI

/// Empty state: a hairline frame with one caption ("Nothing expires in this window."), under a title when it has one
/// ("No invoices yet", f35).
struct EmptyStateView: View {
    let caption: String
    var title: String?

    init(_ caption: String, title: String? = nil) {
        self.caption = caption
        self.title = title
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            if let title {
                Text(title)
                    .textStyle(.bodyStrong16)
                    .foregroundStyle(Color.ms.ink)
            }
            // Under a title the caption is body size, as f35 draws it; alone it is the smaller caption.
            Text(caption)
                .textStyle(title == nil ? .body14 : .body16)
                .foregroundStyle(Color.ms.textSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(Color.ms.line, lineWidth: 1)
        )
    }
}

#Preview("Empty state") {
    VStack(spacing: Spacing.md) {
        EmptyStateView("Nothing expires in this window.")
        EmptyStateView(
            "Your first invoice is issued when the trial ends on January 6, 2027. Each one appears here.",
            title: "No invoices yet"
        )
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
