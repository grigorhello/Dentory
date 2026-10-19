import SwiftUI

/// A row that slides left to reveal one trailing action in danger red, as iOS lists do (To buy's "swipe left →
/// Remove", Appendix B `order.row[id].remove`). It is a horizontal paging scroll view, so it never fights the
/// page's vertical scroll, and VoiceOver reaches the action as the button after the row's content.
///
/// The row reaches past its card's leading padding to the card's edge and gives its content that padding back, so a
/// control at the content's leading edge, such as To buy's checkbox, keeps its whole 44 pt target inside the scroll
/// view, where taps land.
struct SwipeActionRow<Content: View>: View {
    let actionTitle: String
    let actionIdentifier: String
    /// The leading padding of the card the row sits in; `ListCard`'s by default.
    var leadingInset: CGFloat = Spacing.lg
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    static var actionWidth: CGFloat { 88 }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                content()
                    .padding(.leading, leadingInset)
                    .containerRelativeFrame(.horizontal)
                Button(action: action) {
                    Text(actionTitle)
                        .textStyle(.button14)
                        .foregroundStyle(Color.ms.onPrimary)
                        .frame(width: Self.actionWidth)
                        .frame(maxHeight: .infinity)
                        .background(Color.ms.danger)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(actionIdentifier)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .scrollTargetBehavior(SwipeActionSnap(actionWidth: Self.actionWidth))
        .scrollIndicators(.hidden)
        .padding(.leading, -leadingInset)
    }
}

/// Settles a swipe row either closed or with its action fully shown: past half the action's width it opens, so a
/// quick flick opens it as a slow drag does.
private struct SwipeActionSnap: ScrollTargetBehavior {
    let actionWidth: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.x = target.rect.minX > actionWidth / 2 ? actionWidth : 0
    }
}

#Preview("Swipe to remove") {
    ListCard {
        SwipeActionRow(
            actionTitle: "Remove", actionIdentifier: "preview.remove", action: {},
            content: { ListRow("Endo file kit #15-40", caption: "Current 1 · target 5 · Patterson") }
        )
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
