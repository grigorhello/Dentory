import SwiftUI

nonisolated enum IconButtonVariant: CaseIterable, Sendable {
    case ghost, outline, solid
}

nonisolated enum IconButtonSize: CaseIterable, Sendable {
    case small, medium

    var box: CGFloat { self == .small ? 32 : 40 }
    var iconSize: CGFloat { self == .small ? 16 : 20 }
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
            .foregroundStyle(variant == .solid ? Color.ms.onPrimary : Color.ms.ink)
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

    private func background(pressed: Bool) -> Color {
        switch (variant, pressed) {
        case (.ghost, false): .clear
        case (.ghost, true): .ms.surfaceCard
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
