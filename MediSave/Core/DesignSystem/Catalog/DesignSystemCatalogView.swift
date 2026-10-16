#if DEBUG
import SwiftUI

/// Every token and component in every state, for visual review against `design/frames/*.png`.
/// Debug builds only; opened with a long press on the Home title.
struct DesignSystemCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    /// Section to scroll to on appear: colors, type, shape, icons, buttons, forms, selection, steppers, display, list, notices or shell.
    var initialSection: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    CatalogColorsSection().id("colors")
                    CatalogTypeSection().id("type")
                    CatalogShapeSection().id("shape")
                    CatalogIconsSection().id("icons")
                    CatalogButtonsSection().id("buttons")
                    CatalogFormsSection().id("forms")
                    CatalogSelectionSection().id("selection")
                    CatalogDisplaySection().id("display")
                    CatalogShellSection().id("shell")
                }
                .padding(Spacing.page)
                .frame(maxWidth: PageLayout.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                if let initialSection { proxy.scrollTo(initialSection, anchor: .top) }
            }
        }
        .background(Color.ms.canvas)
        .navigationTitle("Design system")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .accessibilityIdentifier("catalog.root")
    }
}

/// An eyebrow-titled block of the catalog.
struct CatalogSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Eyebrow(title)
            content()
        }
    }
}

/// A small secondary caption under a specimen.
struct CatalogCaption: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text).textStyle(.caption12).foregroundStyle(Color.ms.textSecondary)
    }
}

#Preview("Catalog") {
    NavigationStack {
        DesignSystemCatalogView()
    }
}
#endif
