import SwiftUI

/// Button variants (PRD §7). One blue primary per screen; danger only inside confirmation sheets;
/// `outlineOnDark` is the hairline button on the dark procedure card (f6 Edit usage).
nonisolated enum MSButtonVariant: CaseIterable, Sendable {
    case primary, secondary, tertiary, text, danger, outlineOnDark
}

/// `medium` is the 48 pt primary action; `small` is the 36 pt in-card button (its hit target is still 44).
nonisolated enum MSButtonSize: CaseIterable, Sendable {
    case small, medium

    var height: CGFloat { self == .small ? ControlHeight.sm : ControlHeight.lg }
    var iconSize: CGFloat { self == .small ? 14 : 18 }
    var textStyle: TextStyle { self == .small ? .button14 : .button18 }
    var horizontalPadding: CGFloat { self == .small ? Spacing.lg : Spacing.xl }
}

/// The Dentory button look for any `Button`: `Button("Adjust") { }.buttonStyle(.ms(.tertiary))`.
/// A loading button keeps its colors but must also be `.disabled(true)` so nothing can activate it; `MSButton` does that.
struct MSButtonStyle: ButtonStyle {
    var variant: MSButtonVariant = .primary
    var size: MSButtonSize = .medium
    var isFullWidth = false
    var isLoading = false

    func makeBody(configuration: Configuration) -> some View {
        MSButtonSurface(
            variant: variant,
            size: size,
            isFullWidth: isFullWidth,
            isLoading: isLoading,
            isPressed: configuration.isPressed
        ) {
            configuration.label
        }
    }
}

extension ButtonStyle where Self == MSButtonStyle {
    static func ms(
        _ variant: MSButtonVariant = .primary,
        size: MSButtonSize = .medium,
        fullWidth: Bool = false,
        loading: Bool = false
    ) -> MSButtonStyle {
        MSButtonStyle(variant: variant, size: size, isFullWidth: fullWidth, isLoading: loading)
    }
}

/// The drawn button in one state. `MSButtonStyle` uses it; the catalog uses it directly to show the pressed state.
struct MSButtonSurface<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    let variant: MSButtonVariant
    let size: MSButtonSize
    let isFullWidth: Bool
    let isLoading: Bool
    let isPressed: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if isLoading {
                ProgressView().controlSize(.small).tint(foreground)
            }
            label()
        }
        .textStyle(size.textStyle)
        .foregroundStyle(foreground)
        .lineLimit(1)
        // A long label shrinks a little at the largest text sizes rather than lose its end ("10 ite…").
        .minimumScaleFactor(0.7)
        .padding(.horizontal, size.horizontalPadding)
        .frame(maxWidth: isFullWidth ? .infinity : nil)
        .frame(height: size.height)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .frame(minHeight: ControlHeight.hitTarget)
        .animation(Motion.fastAnimation, value: isPressed)
    }

    private var isFilled: Bool {
        switch variant {
        case .primary, .secondary, .danger: true
        case .tertiary, .text, .outlineOnDark: false
        }
    }

    /// Disabled while loading, but drawn in its own colors: the spinner says why it does not respond.
    private var looksEnabled: Bool { isEnabled || isLoading }

    private var foreground: Color {
        if variant == .outlineOnDark { return looksEnabled ? .ms.textOnDark : .ms.mute }
        if !looksEnabled { return isFilled ? .ms.onPrimary : .ms.textDisabled }
        return isFilled ? .ms.onPrimary : .ms.ink
    }

    private var background: Color {
        if !looksEnabled { return isFilled ? .ms.mute : .clear }
        switch (variant, isPressed) {
        case (.primary, false): return .ms.primary
        case (.primary, true): return .ms.primaryActive
        case (.secondary, false): return .ms.ink
        case (.secondary, true): return .ms.inkMid
        case (.tertiary, false): return .ms.surfacePage
        case (.tertiary, true): return .ms.canvasSunken
        case (.text, false): return .clear
        case (.text, true): return .ms.canvasSunken
        case (.danger, false): return .ms.danger
        case (.danger, true): return .ms.dangerActive
        case (.outlineOnDark, false): return .clear
        case (.outlineOnDark, true): return .ms.inkMid
        }
    }

    private var border: Color {
        switch variant {
        case .tertiary: looksEnabled ? .ms.ink : .ms.mute
        case .outlineOnDark: .ms.mute
        default: .clear
        }
    }
}
