import SwiftUI

/// A labelled button with an optional leading icon. For custom labels use `Button` with `.buttonStyle(.ms(...))`.
struct MSButton: View {
    let title: String
    var icon: Icon?
    var variant: MSButtonVariant = .primary
    var size: MSButtonSize = .medium
    var isFullWidth = false
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    init(
        _ title: String,
        icon: Icon? = nil,
        variant: MSButtonVariant = .primary,
        size: MSButtonSize = .medium,
        isFullWidth: Bool = false,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.size = size
        self.isFullWidth = isFullWidth
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                // The spinner takes the icon's place while loading; the button keeps its colors and only stops responding.
                if let icon, !isLoading {
                    IconView(icon, size: size.iconSize)
                }
                Text(title)
            }
        }
        .buttonStyle(.ms(variant, size: size, fullWidth: isFullWidth, loading: isLoading))
        .disabled(isDisabled)
    }
}

#Preview("Variants") {
    VStack(spacing: Spacing.md) {
        ForEach(MSButtonVariant.allCases, id: \.self) { variant in
            HStack(spacing: Spacing.md) {
                MSButton("Add to buy", icon: .shoppingCart, variant: variant) {}
                MSButton("Small", variant: variant, size: .small) {}
                MSButton("Off", variant: variant, size: .small, isDisabled: true) {}
            }
        }
        MSButton("Start procedure · 6 items", icon: .clipboardCheck, isFullWidth: true) {}
        MSButton("Saving", isFullWidth: true, isLoading: true) {}
    }
    .padding(Spacing.page)
    .background(Color.ms.canvas)
}
