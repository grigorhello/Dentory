import SwiftUI

/// A sign-up step's 32 pt title, broken where the frame breaks it (f2: "Create your admin / account"). On one line where
/// the whole title fits (iPad); else the frame's lines, since iOS would move "admin" down rather than leave "account"
/// alone on the second line. VoiceOver reads it as one sentence.
struct OnboardingTitle: View {
    let lines: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            title(lines.joined(separator: " "))
            title(lines.joined(separator: "\n"))
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .textStyle(.display32)
            .foregroundStyle(Color.ms.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(lines.joined(separator: " "))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("onboard.title")
    }
}

#Preview("Titles") {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        OnboardingTitle(lines: ["Create your admin", "account"])
        OnboardingTitle(lines: ["Invite your team"])
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
