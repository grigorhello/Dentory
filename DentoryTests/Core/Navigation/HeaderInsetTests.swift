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
        // iPhone SE and iPad: the safe area is the status bar.
        #expect(PageLayout.headerInset(gap: PageLayout.rootHeaderGap, safeAreaTop: 20) == 8)
        #expect(PageLayout.headerInset(gap: PageLayout.rootHeaderGap, safeAreaTop: 24) == 8)
    }

    @Test func aPushedHeaderSitsSixPointsUnderTheStatusBarButNeverAboveTheSafeArea() {
        #expect(PageLayout.headerInset(gap: PageLayout.pushedHeaderGap, safeAreaTop: 59) == 1)
        #expect(PageLayout.headerInset(gap: PageLayout.pushedHeaderGap, safeAreaTop: 20) == 6)
        // On an iPhone 16 Pro the frames' 60 pt is above the 62 pt safe area: the header starts at the safe area.
        #expect(PageLayout.headerInset(gap: PageLayout.pushedHeaderGap, safeAreaTop: 62) == 0)
        #expect(PageLayout.headerInset(gap: PageLayout.pushedHeaderGap, safeAreaTop: 68) == 0)
    }
}
