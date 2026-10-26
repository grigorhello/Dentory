import SwiftUI

/// One row of History (f9): what changed and why, who and when, and the change on the right: "+4" in success, "−6"
/// in danger, "43 → 41" and "0" in ink. Read-only; a receipt on an admin's Activity opens the invoice it came from,
/// with a chevron (MS-131).
struct ActivityHistoryRow: View {
    let subject: String
    let reason: String
    let who: String
    let delta: String
    let tone: StatusTone?
    var showsDivider = true
    /// What the row opens; nil for a row that opens nothing.
    var open: (() -> Void)?

    var body: some View {
        if let open {
            Button(action: open) { content(navigates: true) }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens the invoice")
        } else {
            content(navigates: false)
                .accessibilityElement(children: .combine)
        }
    }

    private func content(navigates: Bool) -> ActivityHistoryRowContent {
        ActivityHistoryRowContent(
            subject: subject, reason: reason, who: who, delta: delta, tone: tone, showsDivider: showsDivider,
            navigates: navigates
        )
    }
}

#Preview("History rows") {
    ListCard {
        ActivityHistoryRow(
            subject: "Endo file kit #15-40", reason: "Invoice INV-10092", who: "Michael · 9:02 AM", delta: "+4",
            tone: .success, open: {}
        )
        ActivityHistoryRow(
            subject: "Root canal", reason: "Procedure started", who: "Sarah · 8:40 AM", delta: "\u{2212}6",
            tone: .danger
        )
        ActivityHistoryRow(
            subject: "Septocaine 4% 1:100,000", reason: "Physical count", who: "Michael · 4:22 PM", delta: "43 → 41",
            tone: nil, showsDivider: false
        )
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
