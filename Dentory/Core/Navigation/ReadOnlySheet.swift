import SwiftUI

/// "Your clinic is in read-only mode" (MS-142): what still works and where the card goes. Admins can open Billing,
/// the status screen (MS-100 D18: never a payment page); Staff close it.
struct ReadOnlySheet: View {
    let isAdmin: Bool
    let onBilling: () -> Void
    let onClose: () -> Void

    static let title = "Your clinic is in read-only mode"
    static let message = "You can still see everything. "
        + "To make changes, add a card from the link in your billing email."

    var body: some View {
        MSSheet(Self.title, identifier: "readOnly") {
            Text(Self.message)
                .textStyle(.body16)
                .foregroundStyle(Color.ms.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("readOnly.message")
        } primary: {
            if isAdmin {
                VStack(spacing: Spacing.sm) {
                    MSButton("Go to Billing", isFullWidth: true, action: onBilling)
                        .accessibilityIdentifier("readOnly.billing")
                    MSButton("OK", variant: .text, isFullWidth: true, action: onClose)
                        .accessibilityIdentifier("readOnly.ok")
                }
            } else {
                MSButton("OK", isFullWidth: true, action: onClose)
                    .accessibilityIdentifier("readOnly.ok")
            }
        }
    }
}
