import SwiftUI

/// A horizontally scrolling row of filter chips bound to one selected value. Set the Appendix B id (`inv.filter`) on the row.
struct FilterChipRow<Value: Hashable & Sendable>: View {
    @Binding var selection: Value
    let options: [SegmentOption<Value>]
    /// Space before the first and after the last chip; the page padding when the row spans the screen.
    var inset: CGFloat = Spacing.page

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(options) { option in
                    FilterChip(option.label, count: option.count, isSelected: option.value == selection) {
                        selection = option.value
                    }
                }
            }
            .padding(.horizontal, inset)
        }
    }
}

#Preview("Chip row") {
    @Previewable @State var filter = "all"
    FilterChipRow(selection: $filter, options: [
        SegmentOption("all", label: "All"),
        SegmentOption("low", label: "Low", count: 3),
        SegmentOption("expiring", label: "Expiring", count: 2),
        SegmentOption("missing", label: "Missing expiry", count: 1),
        SegmentOption("healthy", label: "Healthy")
    ])
    .padding(.vertical, Spacing.page)
    .background(Color.ms.canvas)
}
