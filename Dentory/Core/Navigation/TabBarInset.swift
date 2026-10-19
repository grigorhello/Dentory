import SwiftUI

extension EnvironmentValues {
    /// The height of the drawn tab bar under a root screen, 0 on pushed screens. `AppTabsView` measures it.
    /// The bar's safe-area inset reaches a tab's scroll content (the last row scrolls clear of the bar) but
    /// not the root layout of its `NavigationStack`, so a root screen that floats something above the bar,
    /// such as the Inventory list's round +, adds this to its bottom padding.
    @Entry var tabBarInset: CGFloat = 0
}
