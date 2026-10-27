import SwiftUI

/// What a History row shows (f9): the subject, why, who and when, the change on the right (under them at the
/// accessibility text sizes, MS-149), and a chevron on a row that opens something (an admin's receipt, MS-131).
struct ActivityHistoryRowContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let subject: String
    let reason: String
    let who: String
    let delta: String
    let tone: StatusTone?
    let showsDivider: Bool
    let navigates: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                layout {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(subject).textStyle(.body14).foregroundStyle(Color.ms.ink)
                        Text(reason).textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
                        Text(who).textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(delta)
                        .textStyle(.bodyStrong16)
                        .foregroundStyle(tone?.foreground ?? Color.ms.ink)
                        .monospacedDigit()
                }
                if navigates {
                    IconView(.chevronRight, size: 20)
                        .foregroundStyle(Color.ms.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, Spacing.md + Spacing.xxs)
            .frame(minHeight: ControlHeight.hitTarget)
            .contentShape(.rect)
            if showsDivider {
                ListDivider()
            }
        }
    }

    private var layout: AnyLayout {
        .row(stacked: dynamicTypeSize.isAccessibilitySize)
    }
}
