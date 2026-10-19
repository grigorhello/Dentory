import SwiftUI

/// A row whose children share the width equally, as f20 draws Adjust beside Add to buy. Its ideal width
/// is the widest child times the count, so inside `ViewThatFits` it wins only when every label fits in
/// its half; a longer label falls through to the next layout.
nonisolated struct EqualWidthHStack: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let width = proposal.width ?? widest * CGFloat(subviews.count) + totalSpacing(for: subviews)
        let cellWidth = cellWidth(in: width, subviews: subviews)
        let height = subviews
            .map { $0.sizeThatFits(ProposedViewSize(width: cellWidth, height: proposal.height)).height }
            .max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cellWidth = cellWidth(in: bounds.width, subviews: subviews)
        var x = bounds.minX
        for subview in subviews {
            subview.place(
                at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                proposal: ProposedViewSize(width: cellWidth, height: bounds.height)
            )
            x += cellWidth + spacing
        }
    }

    private func totalSpacing(for subviews: Subviews) -> CGFloat {
        spacing * CGFloat(max(subviews.count - 1, 0))
    }

    private func cellWidth(in width: CGFloat, subviews: Subviews) -> CGFloat {
        max((width - totalSpacing(for: subviews)) / CGFloat(max(subviews.count, 1)), 0)
    }
}
