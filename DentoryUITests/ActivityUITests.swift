import XCTest

/// Activity (f8, MS-133): the bell, the alerts, where one leads, and the dot that clears once they are seen.
final class ActivityUITests: XCTestCase {
    private let rubberDam = "activity.alert[00000000-0000-4000-8000-000000000701]"

    override func setUp() {
        continueAfterFailure = false
    }

    /// The acceptance flow: bell with its dot → f8's three alerts → Rubber dam opens its product → back to Home, and
    /// the bell has no dot any more.
    @MainActor
    func testTheBellOpensTheAlertsAndLosesItsDot() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let bell = app.buttons["home.header.bell"]
        XCTAssertTrue(bell.waitForExistence(timeout: 5), "No bell")
        XCTAssertEqual(bell.value as? String, "New alerts", "The bell has no dot")
        bell.tap()

        XCTAssertTrue(app.buttons["Alerts · 3"].waitForExistence(timeout: 5), "Activity did not open on Alerts")
        let row = app.buttons[rubberDam]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No Rubber dam alert")
        XCTAssertTrue(row.label.contains("Rubber dam latex-free is out of stock."), "Row reads \(row.label)")
        XCTAssertTrue(app.staticTexts["Bonding agent expires in 59 days."].exists)
        XCTAssertTrue(app.staticTexts["Gutta percha F2 is missing expiry information."].exists)

        row.tap()
        let title = app.staticTexts["product.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "The alert did not open its product")
        XCTAssertEqual(title.label, "Rubber dam latex-free")

        app.buttons["product.back"].tap()
        XCTAssertTrue(app.buttons["activity.back"].waitForExistence(timeout: 5))
        app.buttons["activity.back"].tap()
        let noDot = NSPredicate(format: "value == ''")
        wait(for: [expectation(for: noDot, evaluatedWith: bell)], timeout: 5)
    }

    @MainActor
    func testHistoryWaitsForItsTicket() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff"]
        app.launch()

        let bell = app.buttons["home.header.bell"]
        XCTAssertTrue(bell.waitForExistence(timeout: 5))
        bell.tap()
        XCTAssertTrue(app.buttons["History"].waitForExistence(timeout: 5))
        app.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["History arrives with a later update."].waitForExistence(timeout: 3))
        app.buttons["Alerts · 3"].tap()
        XCTAssertTrue(app.buttons[rubberDam].waitForExistence(timeout: 3), "Staff see the alerts too")
    }
}
