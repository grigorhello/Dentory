import Foundation

/// Corner radii (`tokens/radius.css`): 6 for inputs and chips, 12 for buttons, cards and sheets, pill for badges, full for circles.
nonisolated enum Radius {
    static let none: CGFloat = 0
    static let sm: CGFloat = 6
    static let md: CGFloat = 12
    static let pill: CGFloat = 9999
    static let full: CGFloat = 9999
}
