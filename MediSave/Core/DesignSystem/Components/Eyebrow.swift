import SwiftUI

/// Section eyebrow: uppercase Outfit 14 with 1 pt tracking, the only uppercase in the system.
struct Eyebrow: View {
    let text: String
    var color: Color = .ms.textSecondary

    init(_ text: String, color: Color = .ms.textSecondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .textCase(.uppercase)
            .textStyle(.eyebrow14)
            .foregroundStyle(color)
    }
}

#Preview("Eyebrow") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        Eyebrow("Needs attention")
        Eyebrow("Thursday, October 2")
        CardView(variant: .dark) { Eyebrow("Procedure", color: .ms.mute) }
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
