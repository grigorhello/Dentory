import SwiftUI

/// Temporary tab content until MS-103 brings the real screens. In Debug builds a long press on the Home
/// placeholder opens the design system catalog.
struct TabPlaceholderView: View {
    let tab: AppTab
    #if DEBUG
    @State private var isCatalogPresented = false
    /// `-catalogSection buttons` as a launch argument opens the catalog at that section, for screenshots.
    private let launchSection = UserDefaults.standard.string(forKey: "catalogSection")
    #endif

    var body: some View {
        #if DEBUG
        placeholder
            .onLongPressGesture {
                if tab == .home { isCatalogPresented = true }
            }
            .onAppear {
                if tab == .home, launchSection != nil { isCatalogPresented = true }
            }
            .sheet(isPresented: $isCatalogPresented) {
                NavigationStack {
                    DesignSystemCatalogView(initialSection: launchSection)
                }
            }
        #else
        placeholder
        #endif
    }

    private var placeholder: some View {
        Text(tab.title)
            .textStyle(.body16)
            .foregroundStyle(Color.ms.textBody)
            .accessibilityIdentifier("\(tab.accessibilityIdentifier).placeholder")
    }
}
