import SwiftUI

/// One row of History (f9): what changed and why, who and when, and the change on the right: "+4" in success, "−6"
/// in danger, "43 → 41" in ink, nothing for a change of 0. Read-only.
struct ActivityHistoryRow: View {
    let subject: String
    let reason: String
    let who: String
    let delta: String?
    let tone: StatusTone?
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(subject).textStyle(.body14).foregroundStyle(Color.ms.ink)
                    Text(reason).textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
                    Text(who).textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let delta {
                    Text(delta)
                        .textStyle(.bodyStrong16)
                        .foregroundStyle(tone?.foreground ?? Color.ms.ink)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, Spacing.md + Spacing.xxs)
            .frame(minHeight: ControlHeight.hitTarget)
            if showsDivider {
                ListDivider()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("History rows") {
    ListCard {
        ActivityHistoryRow(
            subject: "Endo file kit #15-40", reason: "Invoice INV-10092", who: "Michael · 9:02 AM", delta: "+4",
            tone: .success
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
