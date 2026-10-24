import SwiftUI

/// One alert (f8, `activity.alert[id]`): the status dot, the sentence over when it opened, and a chevron; the whole row
/// opens what resolves the alert.
struct ActivityAlertRow: View {
    let sentence: String
    let when: String
    let tone: StatusTone
    var showsDivider = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                    Circle()
                        .fill(tone.foreground)
                        .frame(width: Spacing.sm, height: Spacing.sm)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(sentence)
                            .textStyle(.body16)
                            .foregroundStyle(Color.ms.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(when)
                            .textStyle(.body14)
                            .foregroundStyle(Color.ms.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    IconView(.chevronRight, size: 20)
                        .foregroundStyle(Color.ms.textBody)
                }
                .padding(.vertical, Spacing.lg)
                .contentShape(Rectangle())
                if showsDivider {
                    ListDivider()
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Alert rows") {
    ListCard {
        ActivityAlertRow(sentence: "Rubber dam latex-free is out of stock.", when: "Today · 8:40 AM", tone: .danger) {}
        ActivityAlertRow(sentence: "Bonding agent expires in 59 days.", when: "Yesterday", tone: .warning) {}
        ActivityAlertRow(
            sentence: "Gutta percha F2 is missing expiry information.", when: "Yesterday", tone: .info,
            showsDivider: false
        ) {}
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
