import SwiftUI

/// A row of Receive delivery's lists (f22): the name over one caption line, and on the right the quantity ordered or,
/// for an invoice to continue, a chevron. Drawn at the frame's 16 pt over 14 pt, larger than the standard `ListRow`.
struct ReceiveRow: View {
    let title: String
    let caption: String
    var value: String?
    var navigates = false
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title).textStyle(.body16).foregroundStyle(Color.ms.ink)
                    Text(caption).textStyle(.body14).foregroundStyle(Color.ms.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.sm)
                if let value {
                    ListRowValue(value)
                }
                if navigates {
                    IconView(.chevronRight, size: 20).foregroundStyle(Color.ms.textSecondary)
                }
            }
            .padding(.vertical, Spacing.md)
            .frame(minHeight: ControlHeight.hitTarget)
            if showsDivider {
                ListDivider()
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview("Rows") {
    VStack(spacing: Spacing.lg) {
        ListCard {
            ReceiveRow(
                title: "Continue reviewing", caption: "Patterson · 8:55 AM", navigates: true, showsDivider: false
            )
        }
        ListCard {
            ReceiveRow(title: "Needle 27g short", caption: "Patterson · ordered Oct 1", value: "2")
            ReceiveRow(title: "Prophy angles", caption: "Ordered Oct 1", value: "1", showsDivider: false)
        }
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
