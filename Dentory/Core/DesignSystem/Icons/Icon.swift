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
    /// The "…" of a screen's menu (Review invoice's Discard invoice).
    case ellipsis
    case eye
    case eyeOff = "eye-off"
    case fileText = "file-text"
    case fileUp = "file-up"
    /// A picture: the clinic logo's placeholder (f3).
    case image
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
    /// A paper plane: Send invitations (f4).
    case send
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

    /// The template image; draw it with `IconView` so the size and stroke stay consistent. Decorative, so VoiceOver
    /// never reads an asset name such as "Icons/search" (MS-149); the control that holds it carries the label.
    var image: Image {
        Image(decorative: "Icons/\(rawValue)", bundle: .main).renderingMode(.template)
    }
}
