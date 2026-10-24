import SwiftUI

/// "Discard changes?" before leaving Clinic settings with something changed (ticket MS-139): a danger Discard, and
/// Keep editing.
struct DiscardChangesSheet: View {
    let onDiscard: () -> Void
    let onKeep: () -> Void

    var body: some View {
        MSSheet("Discard changes?", identifier: "settings.discardSheet") {
            Text("What you changed here is not saved.")
                .textStyle(.body16)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } primary: {
            VStack(spacing: Spacing.sm) {
                MSButton("Discard", variant: .danger, isFullWidth: true, action: onDiscard)
                    .accessibilityIdentifier("settings.discard")
                MSButton("Keep editing", variant: .text, isFullWidth: true, action: onKeep)
                    .accessibilityIdentifier("settings.keepEditing")
            }
        }
    }
}
