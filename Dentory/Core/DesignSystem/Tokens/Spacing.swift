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
    /// A segment's pill inside the 4 pt padded track (PRD §7 segmented control).
    static let segment: CGFloat = 40

    /// Minimum hit target of anything tappable (PRD §7 accessibility).
    static let hitTarget: CGFloat = 44
}

/// Widths of controls that sit beside a field that takes the rest of the row.
nonisolated enum ControlWidth {
    /// A select of one short word: an invited teammate's Role (f4), the clinic's Currency (f33).
    static let shortSelect: CGFloat = 120
    /// A tab of the tab bar at most, so the four tabs cluster in the middle of a wide bar (f36 to f38).
    static let tabItem: CGFloat = 120
}

/// Page layout limits. The web `container-max` and `sidebar-width` do not apply to the app.
nonisolated enum PageLayout {
    /// iPad content is capped at this width, inside the page gutter, and centred (PRD §7, f36 to f38).
    static let contentMaxWidth: CGFloat = 720
    /// The list inside a sheet scrolls past this height (Appendix C pickers, Review corrections).
    static let sheetListHeight: CGFloat = 360
    /// The status area the frames draw above every screen (PRD §7 "Status bar area 54px"), as tall as the status bar
    /// of an iPhone with the Dynamic Island. Headers are placed under it by `headerInset(gap:safeAreaTop:)`.
    static let frameStatusArea: CGFloat = 54
    /// How far under the status area the frames draw a root header (62 pt from the top: f6, f11, f16, f25).
    static let rootHeaderGap: CGFloat = Spacing.sm
    /// How far under the status area the frames draw a pushed header's row (60 pt from the top: f13, f20, f34).
    static let pushedHeaderGap: CGFloat = Spacing.xs + Spacing.xxs

    /// How far under the safe area's top a header starts so that it sits `gap` under the frames' 54 pt status area. An
    /// iPhone with the Dynamic Island ends its safe area a few points under its 54 pt status bar (62 pt on an iPhone 16
    /// Pro, 59 on an iPhone 16), so part of the gap is already there; a header never starts above the safe area. A
    /// phone with a shorter status bar (an iPhone SE's 20 pt), which no frame draws, keeps its header `gap` under it.
    /// In a regular width (an iPad) the header sits as far from the top as f36 to f38 draw it, the status area being
    /// taller than the iPad's own 24 pt status bar (MS-148).
    static func headerInset(gap: CGFloat, safeAreaTop: CGFloat, isRegularWidth: Bool = false) -> CGFloat {
        let underStatusArea = frameStatusArea + gap - safeAreaTop
        return max(0, isRegularWidth ? underStatusArea : min(gap, underStatusArea))
    }
}
