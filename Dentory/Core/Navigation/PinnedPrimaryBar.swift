import SwiftUI

/// The bottom bar of a pushed screen: hairline top, optional caption in body text (f23), one full-width 48 pt primary
/// (PRD §7). Safe-area aware; content scrolls under nothing.
struct PinnedPrimaryBar<Button: View>: View {
    @Environment(\.appDependencies) private var dependencies
    var caption: String?
    /// The caption's own Appendix B id (`invoice.summary`); `shell.pinned.caption` otherwise.
    var captionIdentifier: String?
    /// Whether the bar tells `ToastCenter` its height so toasts float above it: off in the catalog specimen, and on a
    /// tab's root only while that tab is shown, since the tabs behind it stay alive.
    var reportsHeight = true
    @ViewBuilder let button: () -> Button
    @State private var height: CGFloat = 0

    var body: some View {
        bar
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { newHeight in
                height = newHeight
                if reportsHeight { dependencies.toasts.bottomInset = newHeight }
            }
            .onChange(of: reportsHeight) { _, reports in
                dependencies.toasts.bottomInset = reports ? height : 0
            }
            .onDisappear {
                if reportsHeight { dependencies.toasts.bottomInset = 0 }
            }
    }

    private var bar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.ms.line).frame(height: 1)
            VStack(spacing: Spacing.sm) {
                if let caption {
                    Text(caption)
                        .textStyle(.caption12)
                        .foregroundStyle(Color.ms.textBody)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityIdentifier(captionIdentifier ?? "shell.pinned.caption")
                }
                button()
            }
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
            .contentColumn()
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
