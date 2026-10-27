import SwiftUI

private struct TabSelectedKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False on the screens of a tab that is not chosen, set by `AppTabsView` on each tab's stack.
    var isTabSelected: Bool {
        get { self[TabSelectedKey.self] }
        set { self[TabSelectedKey.self] = newValue }
    }
}

/// Hides a tab's screen from VoiceOver while another tab is chosen. The four tabs stay alive under the chosen one, and
/// `accessibilityHidden` on a `NavigationStack` does not reach the screens it hosts, so each screen hides itself
/// (MS-149).
private struct TabPageModifier: ViewModifier {
    @Environment(\.isTabSelected) private var isTabSelected

    func body(content: Content) -> some View {
        content.accessibilityHidden(!isTabSelected)
    }
}

extension View {
    /// A tab's root screen, hidden from VoiceOver while another tab is chosen.
    func tabPage() -> some View {
        modifier(TabPageModifier())
    }

    /// `navigationDestination(for:destination:)` for the screens pushed on a tab, hidden from VoiceOver while another
    /// tab is chosen, as the tab's root is: a link from a notification can choose another tab over a pushed screen.
    func tabDestination<Route: Hashable, Destination: View>(
        for route: Route.Type,
        @ViewBuilder destination: @escaping (Route) -> Destination
    ) -> some View {
        navigationDestination(for: route) { destination($0).tabPage() }
    }
}
