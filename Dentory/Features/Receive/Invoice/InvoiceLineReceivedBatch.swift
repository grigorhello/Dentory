import SwiftUI

/// A received line's lot and expiry (MS-131), under a hairline as the inputs sat before: "Expiry Mar 2028 · Lot B441",
/// or "No expiry" for stock that went in undated, read-only.
struct InvoiceLineReceivedBatch: View {
    let text: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ListDivider()
            Text(text)
                .textStyle(.body14)
                .foregroundStyle(Color.ms.textBody)
                .accessibilityIdentifier("\(identifier).batch")
        }
        .padding(.top, Spacing.xs)
    }
}
