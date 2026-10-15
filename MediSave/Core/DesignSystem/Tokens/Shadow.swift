import SwiftUI

/// One drop-shadow layer. CSS blur maps to half the SwiftUI radius.
nonisolated struct ShadowLayer: Sendable, Equatable {
    let opacity: Double
    let radius: CGFloat
    let y: CGFloat
}

/// Elevation (`tokens/elevation.css`). Mostly flat: `soft` for toasts and switch knobs, `md` for menus and
/// floating buttons, `lg` for dialogs. The ink hairline is `View.msHairline()`.
nonisolated enum Shadow {
    static let none: [ShadowLayer] = []
    static let soft: [ShadowLayer] = [ShadowLayer(opacity: 0.06, radius: 1, y: 1)]
    static let md: [ShadowLayer] = [
        ShadowLayer(opacity: 0.10, radius: 10, y: 6),
        ShadowLayer(opacity: 0.06, radius: 1, y: 1)
    ]
    static let lg: [ShadowLayer] = [
        ShadowLayer(opacity: 0.16, radius: 24, y: 20),
        ShadowLayer(opacity: 0.06, radius: 3, y: 2)
    ]
}

extension View {
    /// Applies an elevation token. Shadows are ink-tinted, never grey.
    func msShadow(_ layers: [ShadowLayer]) -> some View {
        modifier(ShadowModifier(layers: layers))
    }

    /// The 1 pt ink hairline (`--shadow-hairline`): outline buttons, inputs and items that need a decision.
    func msHairline(_ color: Color = .ms.ink, cornerRadius: CGFloat = Radius.md) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(color, lineWidth: 1)
        )
    }
}

private struct ShadowModifier: ViewModifier {
    let layers: [ShadowLayer]

    func body(content: Content) -> some View {
        layers.reduce(AnyView(content)) { view, layer in
            AnyView(view.shadow(color: Color.ms.ink.opacity(layer.opacity), radius: layer.radius, y: layer.y))
        }
    }
}
