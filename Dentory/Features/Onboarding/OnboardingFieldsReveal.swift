import SwiftUI

/// Keeps sign-up's step 1 clear of the pinned Continue bar while the keyboard is up (MS-136 audit V-04). Once the
/// keyboard has settled, the three fields are scrolled above the bar with the last at the bottom of the room when they
/// all fit there, as they do on an iPhone SE, so they stay in sight whichever has focus; otherwise the focused field
/// and the next one are. It runs as the focus moves, as the keyboard takes its room (which shortens the scroll view)
/// and as the password's hint comes or goes; a newer run cancels one still waiting.
struct OnboardingFieldsReveal: ViewModifier {
    let focus: OnboardingAccountField?
    /// From Full name's label to the end of the password's hint or error.
    let fieldsHeight: CGFloat
    let passwordHint: String?
    let scroller: ScrollViewProxy
    @State private var roomHeight: CGFloat = 0
    @State private var pending: Task<Void, Never>?

    /// How long the keyboard takes to slide in and iOS to scroll the focused field above it; the reveal comes after, or
    /// iOS would put the field back just above the keyboard, under the bar.
    private static let keyboardSettle = Duration.milliseconds(300)

    func body(content: Content) -> some View {
        content
            .onChange(of: focus) { _, field in reveal(field) }
            .onChange(of: passwordHint) { reveal(focus) }
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
            } action: { height in
                roomHeight = height
                reveal(focus)
            }
    }

    private func reveal(_ field: OnboardingAccountField?) {
        pending?.cancel()
        guard let field else { return }
        let target = fieldsHeight <= roomHeight ? OnboardingAccountField.password : field.next ?? field
        pending = Task {
            try? await Task.sleep(for: Self.keyboardSettle)
            guard !Task.isCancelled else { return }
            withAnimation(Motion.baseAnimation) {
                scroller.scrollTo(target, anchor: .bottom)
            }
        }
    }
}
