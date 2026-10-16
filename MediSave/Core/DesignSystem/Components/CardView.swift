import SwiftUI

/// Card surfaces: `soft` cream (default), `outline` ink hairline for items that need a decision,
/// `dark` ink for the one featured block per screen, `raised` canvas with a shadow for floating layers.
nonisolated enum CardVariant: CaseIterable, Sendable {
    case soft, outline, dark, raised
}

/// A 12 pt radius surface padded 16 (PRD §7), stretching to the width it is given.
struct CardView<Content: View>: View {
    var variant: CardVariant = .soft
    var padding: CGFloat = Spacing.lg
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .foregroundStyle(variant == .dark ? Color.ms.textOnDark : Color.ms.ink)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(variant == .outline ? Color.ms.ink : .clear, lineWidth: 1)
            )
            .msShadow(variant == .raised ? Shadow.md : Shadow.none)
    }

    private var background: Color {
        switch variant {
        case .soft: .ms.surfaceCard
        case .outline: .ms.surfacePage
        case .dark: .ms.surfaceDark
        case .raised: .ms.surfaceRaised
        }
    }
}

#Preview("Cards") {
    VStack(spacing: Spacing.lg) {
        ForEach(CardVariant.allCases, id: \.self) { variant in
            CardView(variant: variant) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Eyebrow("Procedure")
                    Text("Root canal").textStyle(.title20)
                    Text("12 supplies · Sarah").textStyle(.body14)
                }
            }
        }
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
