import Testing
@testable import Dentory

/// Headers sit where the frames draw them under their 54 pt status area, measured from the real safe area
/// (MS-136 audit V-06), and never start above it.
struct HeaderInsetTests {
    @Test func aRootHeaderSitsEightPointsUnderTheStatusBar() {
        // iPhone 16 Pro: its safe area already ends 8 pt under the 54 pt status bar, at the frames' 62 pt.
        #expect(PageLayout.headerInset(gap: PageLayout.rootHeaderGap, safeAreaTop: 62) == 0)
        // iPhone 16: 59 pt, so 3 more reach 62.
        #expect(PageLayout.headerInset(gap: PageLayout.rootHeaderGap, safeAreaTop: 59) == 3)
        // iPhone SE: the safe area is its 20 pt status bar, and no frame draws it.
        #expect(PageLayout.headerInset(gap: PageLayout.rootHeaderGap, safeAreaTop: 20) == 8)
    }

    @Test func onAnIPadAHeaderSitsWhereTheIPadFramesDrawIt() {
        // f36 to f38 draw the 54 pt status area above an iPad's header too: its root header starts 62 pt from the top
        // and a pushed header's row 60, under the iPad's own 24 pt status bar (or 20 pt, with a Home button).
        #expect(PageLayout.headerInset(gap: PageLayout.rootHeaderGap, safeAreaTop: 24, isRegularWidth: true) == 38)
        #expect(PageLayout.headerInset(gap: PageLayout.pushedHeaderGap, safeAreaTop: 24, isRegularWidth: true) == 36)
        #expect(PageLayout.headerInset(gap: PageLayout.rootHeaderGap, safeAreaTop: 20, isRegularWidth: true) == 42)
        // Never above the safe area, wherever a window's safe area ends.
        #expect(PageLayout.headerInset(gap: PageLayout.rootHeaderGap, safeAreaTop: 70, isRegularWidth: true) == 0)
    }

    @Test func aPushedHeaderSitsSixPointsUnderTheStatusBarButNeverAboveTheSafeArea() {
        #expect(PageLayout.headerInset(gap: PageLayout.pushedHeaderGap, safeAreaTop: 59) == 1)
        #expect(PageLayout.headerInset(gap: PageLayout.pushedHeaderGap, safeAreaTop: 20) == 6)
        // On an iPhone 16 Pro the frames' 60 pt is above the 62 pt safe area: the header starts at the safe area.
        #expect(PageLayout.headerInset(gap: PageLayout.pushedHeaderGap, safeAreaTop: 62) == 0)
        #expect(PageLayout.headerInset(gap: PageLayout.pushedHeaderGap, safeAreaTop: 68) == 0)
    }
}
