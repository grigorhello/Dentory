import SwiftUI

/// Cream-soft card that holds `ListHeaderRow` and `ListRow`s (PRD §7 lists): 12 pt radius, 16 pt side padding, rows divided by 1 pt lines.
struct ListCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, Spacing.lg)
        .background(Color.ms.surfaceCard, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

/// The 1 pt divider under a row. Pass `showsDivider: false` to the last row.
struct ListDivider: View {
    var body: some View {
        Rectangle().fill(Color.ms.line).frame(height: 1)
    }
}

/// Column captions above the rows ("Expires · Qty · Lot").
struct ListHeaderRow: View {
    let title: String
    var trailing: String?

    init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                Spacer()
                if let trailing {
                    Text(trailing)
                }
            }
            .textStyle(.body16)
            .foregroundStyle(Color.ms.textSecondary)
            .padding(.vertical, Spacing.md)
            ListDivider()
        }
    }
}

#Preview("List card") {
    ListCard {
        ListHeaderRow("Supplies for this procedure", trailing: "Qty")
        ListRow("Septocaine 4% 1:100,000", caption: "Anesthetic · 54 cartridges", badge: .healthy, navigates: true)
        ListRow("Endo file kit #15-40", caption: "0 will remain", captionTone: .warning, value: "1")
        ListRow(
            "Rubber dam latex-free",
            caption: "Not available · 0 in stock",
            captionTone: .danger,
            badge: .outOfStock,
            showsDivider: false
        )
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
