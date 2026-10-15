import XCTest

final class TabNavigationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTappingEachTabShowsItsScreen() {
        let app = XCUIApplication()
        app.launch()

        for title in ["Home", "Inventory", "Procedures", "To buy"] {
            let tab = app.tabBars.buttons[title]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing tab \(title)")
            tab.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), "\(title) screen did not appear")
        }
    }
}
