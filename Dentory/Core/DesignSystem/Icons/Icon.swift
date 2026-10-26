import SwiftUI

/// The Lucide icons the design uses (ISC, `Assets.xcassets/Icons`, 24-unit grid, 1.75 stroke, template images).
nonisolated enum Icon: String, CaseIterable, Sendable {
    case bell
    case calendar
    case camera
    case check
    case chevronDown = "chevron-down"
    case chevronLeft = "chevron-left"
    case chevronRight = "chevron-right"
    case clipboardCheck = "clipboard-check"
    case clipboardList = "clipboard-list"
    case creditCard = "credit-card"
    case download
    case eye
    case eyeOff = "eye-off"
    case fileText = "file-text"
    case fileUp = "file-up"
    case info
    case layoutGrid = "layout-grid"
    case lifeBuoy = "life-buoy"
    case logOut = "log-out"
    case minus
    case package
    case pencil
    case penLine = "pen-line"
    case plus
    case search
    case settings
    case shoppingCart = "shopping-cart"
    case slidersHorizontal = "sliders-horizontal"
    case trash = "trash-2"
    case truck
    case upload
    case userPlus = "user-plus"
    case user
    case users
    case x

    /// The template image; draw it with `IconView` so the size and stroke stay consistent.
    var image: Image {
        Image("Icons/\(rawValue)", bundle: .main).renderingMode(.template)
    }
}
