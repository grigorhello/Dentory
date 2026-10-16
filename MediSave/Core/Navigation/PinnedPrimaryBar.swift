import SwiftUI

/// The bottom bar of a pushed screen: hairline top, optional caption, one full-width 48 pt primary
/// (PRD §7). Safe-area aware; content scrolls under nothing.
struct PinnedPrimaryBar<Button: View>: View {
    var caption: String?
    @ViewBuilder let button: () -> Button

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.ms.line).frame(height: 1)
            VStack(spacing: Spacing.sm) {
                if let caption {
                    Text(caption)
                        .textStyle(.caption12)
                        .foregroundStyle(Color.ms.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityIdentifier("shell.pinned.caption")
                }
                button()
            }
            .padding(.horizontal, Spacing.page)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
            .frame(maxWidth: PageLayout.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color.ms.surfacePage)
    }
}

extension View {
    /// Pins a primary bar to the bottom of the screen, inset from the content.
    func pinnedPrimaryBar<Button: View>(
        caption: String? = nil,
        @ViewBuilder button: @escaping () -> Button
    ) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            PinnedPrimaryBar(caption: caption, button: button)
        }
    }
}

#Preview("Pinned bar") {
    Color.ms.canvas
        .pinnedPrimaryBar(caption: "Resolve every line to continue.") {
            MSButton("Confirm & receive", isFullWidth: true, isDisabled: true) {}
        }
}
