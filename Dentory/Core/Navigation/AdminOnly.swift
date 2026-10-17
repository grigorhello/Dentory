import SwiftUI

private struct SessionKey: EnvironmentKey {
    static let defaultValue: Session? = nil
}

extension EnvironmentValues {
    /// The signed-in session, set by `RootView`; nil while signed out.
    var session: Session? {
        get { self[SessionKey.self] }
        set { self[SessionKey.self] = newValue }
    }
}

/// Removes the view for Staff. Role gating hides controls; it never renders a disabled one (CLAUDE.md).
struct AdminOnlyModifier: ViewModifier {
    @Environment(\.session) private var session

    func body(content: Content) -> some View {
        if session?.isAdmin == true {
            content
        }
    }
}

extension View {
    func adminOnly() -> some View {
        modifier(AdminOnlyModifier())
    }
}
