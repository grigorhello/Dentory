import XCTest

final class TabNavigationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTappingEachTabShowsItsScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let expected: [(tab: String, title: String)] = [
            ("Inventory", "Inventory"), ("Procedures", "Procedures"), ("To buy", "To buy"), ("Home", "Smile Dental")
        ]
        for (tab, title) in expected {
            // Not app.tabBars: on iPad (iOS 18+) the tabs are a floating top bar with no TabBar element.
            let button = app.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing tab \(tab)")
            button.tap()
            let heading = app.staticTexts[title]
            XCTAssertTrue(heading.waitForExistence(timeout: 5), "\(tab) screen did not appear")
        }
    }

    @MainActor
    func testPushedScreenHidesTheTabBarAndOpensASheet() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let demo = app.descendants(matching: .any)["shell.demo.push"]
        XCTAssertTrue(demo.waitForExistence(timeout: 5))
        demo.tap()

        XCTAssertTrue(app.staticTexts["shell.demo.title"].waitForExistence(timeout: 5), "Pushed screen did not appear")
        XCTAssertFalse(app.buttons["Inventory"].isHittable, "Tab bar is visible on a pushed screen")
        XCTAssertTrue(app.buttons["shell.demo.primary"].exists, "Pinned primary bar is missing")

        app.buttons["shell.demo.sheet"].tap()
        let sheetTitle = app.staticTexts["adjust.title"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "Sheet did not open")
        app.buttons["adjust.save"].tap()
        XCTAssertTrue(sheetTitle.waitForNonExistence(timeout: 5), "Sheet did not close")

        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "Toast did not show")
        app.buttons["toast.undo"].tap()
        XCTAssertTrue(toast.waitForNonExistence(timeout: 5), "Undo did not hide the toast")

        app.buttons["shell.demo.back"].tap()
        XCTAssertTrue(app.buttons["Inventory"].waitForExistence(timeout: 5), "Tab bar did not return")
    }
}
