import Foundation

/// The four root tabs, in tab bar order (PRD §3).
enum AppTab: String, CaseIterable, Identifiable {
    case home
    case inventory
    case procedures
    case toBuy

    var id: Self { self }

    var title: String {
        switch self {
        case .home: String(localized: "Home")
        case .inventory: String(localized: "Inventory")
        case .procedures: String(localized: "Procedures")
        case .toBuy: String(localized: "To buy")
        }
    }

    /// Lucide icon of the tab (f25).
    var icon: Icon {
        switch self {
        case .home: .layoutGrid
        case .inventory: .package
        case .procedures: .clipboardCheck
        case .toBuy: .clipboardList
        }
    }

    var accessibilityIdentifier: String {
        "tab.\(rawValue)"
    }
}
