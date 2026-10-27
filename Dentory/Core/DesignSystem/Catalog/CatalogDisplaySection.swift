#if DEBUG
import SwiftUI

struct CatalogDisplaySection: View {
    @State private var batchQuantity = 20

    var body: some View {
        CatalogSection("Status badges") {
            CatalogFlowLayout(spacing: Spacing.sm) {
                ForEach(StatusBadgeKind.allCases, id: \.self) { kind in
                    StatusBadge(kind)
                }
            }
            CatalogFlowLayout(spacing: Spacing.sm) {
                ForEach(StatusBadgeKind.allCases, id: \.self) { kind in
                    StatusBadge(kind, size: .small, showsDot: true)
                }
                StatusBadge(.healthy, tone: .neutral, showsDot: true)
                StatusBadge("in 60 days", tone: .warning, size: .small)
            }
        }
        CatalogSection("Cards") {
            ForEach(CardVariant.allCases, id: \.self) { variant in
                CardView(variant: variant) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Eyebrow("Procedure", color: variant == .dark ? .ms.mute : .ms.textSecondary)
                        Text("Root canal").textStyle(.title20)
                        Text("12 supplies · Sarah").textStyle(.body14)
                        CatalogCaption(String(describing: variant))
                    }
                }
            }
        }
        CatalogSection("List card and rows") {
            ListCard {
                ListHeaderRow("Expires", trailing: "Lot")
                ListRow(
                    "Septocaine 4% 1:100,000", caption: "Anesthetic · 54 cartridges", badge: .healthy, navigates: true
                )
                ListRow("Dec 1, 2026", caption: "in 60 days", captionTone: .warning, value: "20")
                ListRow(
                    "Rubber dam latex-free",
                    caption: "Not available · 0 in stock",
                    captionTone: .danger,
                    badge: .outOfStock
                )
                ListRow("Composite A2", caption: "Current 2 · target 6 · Patterson") {
                    QuantityStepper(value: $batchQuantity, reference: 20, name: "Gloves", identifier: "catalog.row[4]")
                }
                ListRow("Count stock", navigates: true, showsDivider: false)
            }
        }
        .id("list")
        CatalogSection("Eyebrow and notices") {
            Eyebrow("Needs attention")
            Notice("AI read 4 lines. Check each one, then confirm.")
            Notice("Stock levels update immediately.", tone: .warning)
            Notice("Invoice received. 4 products updated.", tone: .success)
            Notice("Couldn't save. Try again.", tone: .danger)
        }
        .id("notices")
        CatalogSection("Empty and loading") {
            EmptyStateView("Nothing expires in this window.")
            ListCard {
                SkeletonRow()
                SkeletonRow()
                SkeletonRow(showsDivider: false)
            }
            DocumentPlaceholder()
        }
    }
}
#endif
