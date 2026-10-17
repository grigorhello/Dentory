#if DEBUG
import SwiftUI

struct CatalogButtonsSection: View {
    var body: some View {
        CatalogSection("Buttons") {
            ForEach(MSButtonVariant.allCases, id: \.self) { variant in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    CatalogCaption("\(String(describing: variant)) · default, pressed, disabled, loading, small")
                    CatalogFlowLayout(spacing: Spacing.sm) {
                        MSButton("Adjust", icon: .slidersHorizontal, variant: variant) {}
                        MSButtonSurface(
                            variant: variant, size: .medium, isFullWidth: false, isLoading: false, isPressed: true
                        ) {
                            Text("Pressed")
                        }
                        MSButton("Disabled", variant: variant, isDisabled: true) {}
                        MSButton("Saving", variant: variant, isLoading: true) {}
                        MSButton("Yes, match", variant: variant, size: .small) {}
                        MSButton("Off", variant: variant, size: .small, isDisabled: true) {}
                    }
                }
            }
            MSButton("Start procedure · 6 items", icon: .clipboardCheck, isFullWidth: true) {}
            CatalogCaption("Full width primary action, 48 pt")
        }
        CatalogSection("Icon buttons") {
            ForEach(IconButtonVariant.allCases, id: \.self) { variant in
                HStack(spacing: Spacing.sm) {
                    IconButton(.pencil, label: "Edit", variant: variant) {}
                    IconButton(.x, label: "Close", variant: variant, size: .small) {}
                    IconButton(.bell, label: "Alerts", variant: variant) {}.disabled(true)
                    CatalogCaption("\(String(describing: variant)) · medium, small, disabled")
                }
            }
        }
        CatalogSection("Floating add") {
            FloatingAddButton(label: "Add item") {}
        }
    }
}
#endif
