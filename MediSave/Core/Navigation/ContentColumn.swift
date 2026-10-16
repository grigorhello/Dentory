import SwiftUI

/// Caps content at 720 pt and centres it (PRD §7, iPad f36). Every screen's content sits in one.
struct ContentColumn<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: PageLayout.contentMaxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Wraps the view in a `ContentColumn`.
    func contentColumn() -> some View {
        ContentColumn { self }
    }
}
