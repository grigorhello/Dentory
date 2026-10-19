import SwiftUI

/// A row that slides left to reveal one trailing action in danger red, as iOS lists do (To buy's "swipe left →
/// Remove", Appendix B `order.row[id].remove`). It is a horizontal paging scroll view, so it never fights the
/// page's vertical scroll, and VoiceOver reaches the action as the button after the row's content.
struct SwipeActionRow<Content: View>: View {
    let actionTitle: String
    let actionIdentifier: String
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    static var actionWidth: CGFloat { 88 }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                content()
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
