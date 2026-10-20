import SwiftUI

/// A row of Billing's cards (f34): the title in ink, an optional value in grey, and a chevron when it leads on.
struct BillingRow: View {
    let title: String
    var value: String?
    var navigates = true
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                // The value sits beside the title while both fit whole, else under it (a long address, large text).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.md) {
                        titleText.frame(maxWidth: .infinity, alignment: .leading)
                        valueText?.fixedSize()
                    }
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        titleText
                        valueText
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if navigates {
                    IconView(.chevronRight, size: 20).foregroundStyle(Color.ms.ink)
                }
            }
            .padding(.vertical, Spacing.lg)
            .frame(minHeight: ControlHeight.hitTarget)
            if showsDivider {
                ListDivider()
            }
        }
        .contentShape(Rectangle())
    }

    private var titleText: some View {
        Text(title).textStyle(.body16).foregroundStyle(Color.ms.ink)
    }

    private var valueText: (some View)? {
        value.map { Text($0).textStyle(.body14).foregroundStyle(Color.ms.textSecondary) }
    }
}
