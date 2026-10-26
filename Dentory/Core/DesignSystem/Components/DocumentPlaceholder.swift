import SwiftUI

/// A document being read (Review invoice's reading state, f23; Appendix B `invoice.reading`): a sunken cream page with
/// a document icon, as the prototype draws it, breathing like the skeleton rows while the reading runs. It holds still
/// when Reduce Motion is on, and is hidden from VoiceOver: the text beside it says what is happening.
struct DocumentPlaceholder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let pageSize = CGSize(width: 120, height: 160)
    static let iconSize: CGFloat = 36

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            page.opacity(reduceMotion ? 1 : SkeletonRow.opacity(at: context.date))
        }
        .accessibilityHidden(true)
    }

    private var page: some View {
        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .fill(Color.ms.canvasSunken)
            .frame(width: Self.pageSize.width, height: Self.pageSize.height)
            .overlay {
                IconView(.fileText, size: Self.iconSize)
                    .foregroundStyle(Color.ms.mute)
            }
    }
}

#Preview("Document placeholder") {
    DocumentPlaceholder()
        .padding(Spacing.page)
        .background(Color.ms.canvas)
}
