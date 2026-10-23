import SwiftUI

/// The one-line explainer before the iOS prompt (PRD §8): what the alerts are, "Turn on" and "Not now".
struct PushExplainerSheet: View {
    let push: PushNotifications

    var body: some View {
        MSSheet("Notifications", identifier: "push") {
            Text(push.explainerText)
                .textStyle(.body16)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("push.message")
        } primary: {
            VStack(spacing: Spacing.sm) {
                MSButton("Turn on", isFullWidth: true, action: turnOn)
                    .accessibilityIdentifier("push.turnOn")
                MSButton("Not now", variant: .text, isFullWidth: true, action: push.notNow)
                    .accessibilityIdentifier("push.notNow")
            }
        }
    }

    private func turnOn() {
        Task { await push.turnOn() }
    }
}
