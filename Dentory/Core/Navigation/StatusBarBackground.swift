import SwiftUI

extension View {
    /// Paints the status bar in the page colour. A form drawn without the system bar (admin sign-up, Join) scrolls
    /// under the status bar; without this its text would run behind the time and the carrier (MS-136 audit V-17).
    func statusBarBackground() -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: 0)
                .background(Color.ms.surfacePage, ignoresSafeAreaEdges: .top)
        }
    }
}
