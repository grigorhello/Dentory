import SwiftUI

nonisolated enum IconButtonVariant: CaseIterable, Sendable {
    case ghost, outline, solid
    /// A ghost button in secondary text, for an action on a list row (the template pencil of f11).
    case quiet
}

nonisolated enum IconButtonSize: CaseIterable, Sendable {
    case small, medium
    /// A row's own action as the frames draw it (the template pencil of f11, a supply's remove X of f13 and f15): a
    /// 24 pt icon in the medium box.
    case row

    var box: CGFloat { self == .small ? 32 : 40 }

    var iconSize: CGFloat {
        switch self {
        case .small: 16
        case .medium: 20
        case .row: 24
        }
    }
}

/// Square icon-only button. Always give it a label: it is what VoiceOver reads.
struct IconButton: View {
    let icon: Icon
    let label: String
    var variant: IconButtonVariant = .ghost
    var size: IconButtonSize = .medium
    let action: () -> Void

    init(
        _ icon: Icon,
        label: String,
        variant: IconButtonVariant = .ghost,
        size: IconButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.variant = variant
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            IconView(icon, size: size.iconSize)
        }
        .buttonStyle(IconButtonStyle(variant: variant, size: size))
        .accessibilityLabel(label)
    }
}

/// The icon button look; `IconButton` applies it, the catalog uses it for state previews.
struct IconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let variant: IconButtonVariant
    let size: IconButtonSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .frame(width: size.box, height: size.box)
            .background(
                background(pressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(variant == .outline ? Color.ms.ink : .clear, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .frame(minWidth: ControlHeight.hitTarget, minHeight: ControlHeight.hitTarget)
            .contentShape(Rectangle())
            .animation(Motion.fastAnimation, value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .solid: .ms.onPrimary
        case .quiet: .ms.textSecondary
        case .ghost, .outline: .ms.ink
        }
    }

    private func background(pressed: Bool) -> Color {
        switch (variant, pressed) {
        case (.ghost, false), (.quiet, false): .clear
        case (.ghost, true), (.quiet, true): .ms.surfaceCard
        case (.outline, false): .ms.surfacePage
        case (.outline, true): .ms.surfaceCard
        case (.solid, false): .ms.primary
        case (.solid, true): .ms.primaryActive
        }
    }
}

#Preview("Icon buttons") {
    HStack(spacing: Spacing.lg) {
        ForEach(IconButtonVariant.allCases, id: \.self) { variant in
            IconButton(.pencil, label: "Edit", variant: variant) {}
            IconButton(.x, label: "Close", variant: variant, size: .small) {}
        }
        IconButton(.bell, label: "Alerts") {}.disabled(true)
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
