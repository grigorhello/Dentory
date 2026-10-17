import SwiftUI

/// Draws a Lucide icon in the current foreground style. 20 pt by default (PRD §7); decorative, so hidden from VoiceOver.
/// Put the label on the control that contains it.
struct IconView: View {
    let icon: Icon
    var size: CGFloat = 20

    init(_ icon: Icon, size: CGFloat = 20) {
        self.icon = icon
        self.size = size
    }

    var body: some View {
        icon.image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview("Icons") {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 6), spacing: Spacing.md) {
        ForEach(Icon.allCases, id: \.self) { icon in
            IconView(icon)
        }
    }
    .foregroundStyle(Color.ms.ink)
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
