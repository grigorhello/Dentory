import Observation
import SwiftUI

/// The selected tab and the pushed path of each tab. Features push their own route values
/// (`InventoryRoute.product(id)`) and read it from the environment.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab
    /// Items on the To buy list, shown as the tab's badge; MS-128 keeps it current. Hidden at 0.
    var toBuyCount = 0
    /// Set by Home before selecting the Inventory tab; the list applies it once and clears it (MS-115).
    var inventoryFilter: InventoryFilter?
    /// A category name set by Inventory value (MS-135) before selecting the Inventory tab; applied once, like the filter.
    var inventoryCategory: String?
    private var paths: [AppTab: NavigationPath] = [:]

    init(selectedTab: AppTab = .home, inventoryFilter: InventoryFilter? = nil) {
        self.selectedTab = selectedTab
        self.inventoryFilter = inventoryFilter
    }

    func path(for tab: AppTab) -> NavigationPath {
        paths[tab] ?? NavigationPath()
    }

    /// The binding a tab's `NavigationStack` owns.
    func pathBinding(for tab: AppTab) -> Binding<NavigationPath> {
        Binding(
            get: { [self] in path(for: tab) },
            set: { [self] in paths[tab] = $0 }
        )
    }

    func push<Route: Hashable>(_ route: Route, on tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        var path = path(for: target)
        path.append(route)
        paths[target] = path
    }

    func pop(on tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        var path = path(for: target)
        guard !path.isEmpty else { return }
        path.removeLast()
        paths[target] = path
    }

    func popToRoot(on tab: AppTab? = nil) {
        paths[tab ?? selectedTab] = NavigationPath()
    }

    /// Selects a tab; selecting the current one again returns to its root, as the system tab bar does.
    func select(_ tab: AppTab) {
        if tab == selectedTab {
            popToRoot(on: tab)
        } else {
            selectedTab = tab
        }
    }
}
