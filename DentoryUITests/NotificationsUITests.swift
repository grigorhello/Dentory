import XCTest

/// Push notifications (PRD §8, MS-144): the explainer after sign-in, and the links a tapped notification opens.
final class NotificationsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// `-pushExplainer` starts the device as one that never offered notifications; "Not now" closes it.
    @MainActor
    func testTheExplainerOffersNotificationsOnce() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-pushExplainer"]
        app.launch()

        let message = app.staticTexts["push.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5), "No explainer after sign-in")
        XCTAssertEqual(app.staticTexts["push.title"].label, "Notifications")
        XCTAssertEqual(message.label, "Get alerts for out-of-stock items, expiring stock and invoices ready to review.")
        XCTAssertTrue(app.buttons["push.turnOn"].exists)
        app.buttons["push.notNow"].tap()
        XCTAssertTrue(message.waitForNonExistence(timeout: 5), "Not now did not close it")
        XCTAssertTrue(app.buttons["home.header.bell"].exists, "Home is not behind it")
    }

    @MainActor
    func testStaffAreNotPromisedDeliveryAlerts() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff", "-pushExplainer"]
        app.launch()

        let message = app.staticTexts["push.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5), "No explainer after sign-in")
        XCTAssertEqual(message.label, "Get alerts for out-of-stock items and expiring stock.")
    }

    /// The link of an out-of-stock push opens the product on the Inventory tab; a delivery's opens Receive delivery.
    @MainActor
    func testANotificationsLinkOpensWhatItsAlertOpens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.buttons["home.header.bell"].waitForExistence(timeout: 5))

        app.open(try XCTUnwrap(URL(string: "dentory://product/00000000-0000-4000-8000-0000000000d1")))
        let title = app.staticTexts["product.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "The product did not open")
        XCTAssertEqual(title.label, "Septocaine 4% 1:100,000")
        app.buttons["product.back"].tap()
        XCTAssertTrue(app.buttons["inv.countStock"].waitForExistence(timeout: 5), "Back did not land on Inventory")

        app.open(try XCTUnwrap(URL(string: "dentory://delivery")))
        XCTAssertTrue(app.staticTexts["receive.title"].waitForExistence(timeout: 5), "Receive delivery did not open")
    }
}
