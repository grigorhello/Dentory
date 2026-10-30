import SwiftUI

/// An iPad sheet as wide as the content column and as tall as its content (PRD §6.10: "sheets are centred at the same
/// width", MS-148), where the system's form sheet is 580 pt wide and at most 632 pt tall, so a long sheet scrolled in
/// part of a tall screen. The system keeps it inside the screen and above the keyboard. A phone's sheet is unchanged.
@available(iOS 18.0, *)
nonisolated struct ColumnSheetSizing: PresentationSizing {
    /// The sheet's content as measured; until then its height at the column's width.
    let contentHeight: CGFloat

    func proposedSize(for root: PresentationSizingRoot, context: PresentationSizingContext) -> ProposedViewSize {
        let width = PageLayout.contentMaxWidth
        let height = contentHeight > 0
            ? contentHeight
            : root.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        return ProposedViewSize(width: width, height: height)
    }
}

extension View {
    /// Sizes the sheet presenting this view with `ColumnSheetSizing`; on iOS 17 an iPad keeps the system's form sheet.
    @ViewBuilder
    func columnSheetSizing(contentHeight: CGFloat) -> some View {
        if #available(iOS 18.0, *) {
            presentationSizing(ColumnSheetSizing(contentHeight: contentHeight))
        } else {
            self
        }
    }
}
