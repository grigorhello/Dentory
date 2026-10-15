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

    var systemImage: String {
        switch self {
        case .home: "square.grid.2x2"
        case .inventory: "shippingbox"
        case .procedures: "list.clipboard"
        case .toBuy: "list.bullet.clipboard"
        }
    }

    var accessibilityIdentifier: String {
        "tab.\(rawValue)"
    }
}
