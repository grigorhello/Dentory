import SwiftUI

/// "Discard this count?" (Appendix C `cancelCount`): asked only when corrections are pending. Discard count
/// leaves count mode without writing anything; Keep counting closes the sheet.
struct DiscardCountSheet: View {
    let message: String
    let onDiscard: () -> Void
    let onKeep: () -> Void

    var body: some View {
        MSSheet("Discard this count?", identifier: "cancelCount") {
            Text(message)
                .textStyle(.body16)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("cancelCount.message")
        } primary: {
            VStack(spacing: Spacing.sm) {
                MSButton("Discard count", variant: .danger, isFullWidth: true, action: onDiscard)
                    .accessibilityIdentifier("cancelCount.discard")
                MSButton("Keep counting", variant: .text, isFullWidth: true, action: onKeep)
                    .accessibilityIdentifier("cancelCount.keep")
            }
        }
    }
}

#Preview("Discard this count?") {
    Color.ms.canvas
        .msSheet(isPresented: .constant(true)) {
            DiscardCountSheet(message: "2 changes. Inventory stays as it is.", onDiscard: {}, onKeep: {})
        }
}
