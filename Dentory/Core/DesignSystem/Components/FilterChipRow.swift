import SwiftUI

/// A horizontally scrolling row of filter chips bound to one selected value. Set the Appendix B id (`inv.filter`) on the row.
/// `leading` puts chips before the options, such as the removable category chip of the Inventory list.
struct FilterChipRow<Value: Hashable & Sendable, Leading: View>: View {
    @Binding var selection: Value
    let options: [SegmentOption<Value>]
    /// Space before the first and after the last chip; the page padding when the row spans the screen.
    var inset: CGFloat = Spacing.page
    @ViewBuilder let leading: () -> Leading

    init(
        selection: Binding<Value>,
        options: [SegmentOption<Value>],
        inset: CGFloat = Spacing.page,
        @ViewBuilder leading: @escaping () -> Leading
    ) {
        _selection = selection
        self.options = options
        self.inset = inset
        self.leading = leading
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                leading()
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

extension FilterChipRow where Leading == EmptyView {
    init(selection: Binding<Value>, options: [SegmentOption<Value>], inset: CGFloat = Spacing.page) {
        self.init(selection: selection, options: options, inset: inset) { EmptyView() }
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
