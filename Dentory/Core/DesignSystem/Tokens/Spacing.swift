import Foundation

/// Spacing scale (`tokens/spacing.css`): 4 pt base. Cards pad `lg`, stacks `md`, page sides `xl` minus 4 (PRD §7: 20 pt).
nonisolated enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
    static let xxxxl: CGFloat = 64

    /// Side padding of every screen (PRD §7).
    static let page: CGFloat = 20
}

/// Control heights (`tokens/spacing.css`). `lg` is 48 on mobile (PRD §7 primary action), not the web's 51.
nonisolated enum ControlHeight {
    static let sm: CGFloat = 36
    static let md: CGFloat = 44
    static let lg: CGFloat = 48

    /// Minimum hit target of anything tappable (PRD §7 accessibility).
    static let hitTarget: CGFloat = 44
}

/// Page layout limits. The web `container-max` and `sidebar-width` do not apply to the app.
nonisolated enum PageLayout {
    /// iPad content is capped at this width and centred (PRD §7).
    static let contentMaxWidth: CGFloat = 720
    /// The list inside a sheet scrolls past this height (Appendix C pickers, Review corrections).
    static let sheetListHeight: CGFloat = 360
}
