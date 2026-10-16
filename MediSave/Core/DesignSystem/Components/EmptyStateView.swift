import SwiftUI

/// Empty state: a hairline frame with one caption ("Nothing expires in this window.").
struct EmptyStateView: View {
    let caption: String

    init(_ caption: String) {
        self.caption = caption
    }

    var body: some View {
        Text(caption)
            .textStyle(.body14)
            .foregroundStyle(Color.ms.textSecondary)
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
    EmptyStateView("Nothing expires in this window.")
        .padding(Spacing.page)
        .background(Color.ms.canvas)
}
