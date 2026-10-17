import XCTest

final class HomeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAdminHomeShowsTheTilesAndNavigates() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Smile Dental"].waitForExistence(timeout: 5))
        for id in ["home.tile.toBuy", "home.tile.expiring", "home.tile.missingExpiry",
                   "home.procedure.start", "home.procedure.latest", "home.procedure.editUsage",
                   "home.tile.inventoryValue", "home.tile.atRisk", "home.receive", "home.header.bell"] {
            XCTAssertTrue(app.descendants(matching: .any)[id].waitForExistence(timeout: 3), "Missing \(id)")
        }
        let value = app.descendants(matching: .any)["home.tile.inventoryValue"]
        XCTAssertTrue(value.label.contains("$12,420"), "Inventory value reads \(value.label)")
        let latest = app.descendants(matching: .any)["home.procedure.latest"]
        XCTAssertTrue(latest.label.contains("12 supplies · Sarah"), "Latest reads \(latest.label)")

        app.descendants(matching: .any)["home.tile.toBuy"].tap()
        XCTAssertTrue(app.staticTexts["tab.toBuy.header.title"].waitForExistence(timeout: 5), "To buy did not open")
        app.buttons["Home"].tap()

        app.descendants(matching: .any)["home.receive"].tap()
        XCTAssertTrue(app.staticTexts["receive.title"].waitForExistence(timeout: 5), "Receive delivery did not open")
        app.buttons["receive.back"].tap()
        XCTAssertTrue(app.staticTexts["Smile Dental"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testStaffHomeHidesReceiveDelivery() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["home.tile.toBuy"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["home.receive"].exists, "Staff sees Receive delivery")
    }
}
