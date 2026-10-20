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
                Text(title)
                    .textStyle(.body16)
                    .foregroundStyle(Color.ms.ink)
                    .layoutPriority(1)
                Spacer(minLength: Spacing.sm)
                if let value {
                    Text(value)
                        .textStyle(.body14)
                        .foregroundStyle(Color.ms.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
}
