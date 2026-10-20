import XCTest

/// Billing (f34) from Account: the demo clinic's trial with the lifetime promotion and its Visa card, and a card added
/// from a trial without one showing up without a restart.
final class BillingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAnAdminSeesTheTrialThePriceAndTheCard() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openBilling(in: app)

        let trial = app.descendants(matching: .any)["billing.trial"]
        XCTAssertTrue(trial.label.contains("3 months"), "The trial reads \(trial.label)")
        XCTAssertTrue(trial.label.contains("Ends January 6, 2027"), "The trial reads \(trial.label)")
        let price = app.descendants(matching: .any)["billing.price"]
        XCTAssertTrue(price.label.contains("$49.50 / month"), "The price reads \(price.label)")
        XCTAssertTrue(price.label.contains("50% off for life"), "The price reads \(price.label)")
        XCTAssertEqual(app.staticTexts["billing.card"].label, "Visa ·· 4242")
        XCTAssertEqual(app.buttons["billing.paymentMethod"].label, "Change")
        XCTAssertTrue(app.buttons["billing.invoices"].label.contains("None yet"))
        XCTAssertTrue(app.buttons["billing.emails"].label.contains("owner@smiledental.ca"))
    }

    @MainActor
    func testACardAddedDuringTheTrialShowsWithoutARestart() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-billingNoCard", "YES"]
        app.launch()
        openBilling(in: app)

        let add = app.buttons["billing.paymentMethod"]
        XCTAssertEqual(add.label, "Add")
        XCTAssertFalse(app.staticTexts["billing.card"].exists, "A card before one was added")
        add.tap()
        let card = app.staticTexts["billing.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "The card did not show")
        XCTAssertEqual(card.label, "Visa ·· 4242")
        XCTAssertEqual(app.buttons["billing.paymentMethod"].label, "Change")
    }

    @MainActor
    private func openBilling(in app: XCUIApplication) {
        let account = app.buttons["home.header.account"]
        XCTAssertTrue(account.waitForExistence(timeout: 5), "Home has no account button")
        account.tap()
        let billing = app.buttons["more.billing"]
        XCTAssertTrue(billing.waitForExistence(timeout: 5), "Account did not open")
        billing.tap()
        let title = app.staticTexts["billing.title"]
        if !title.waitForExistence(timeout: 2) { billing.tap() }
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Billing did not open")
        let trial = app.descendants(matching: .any)["billing.trial"]
        XCTAssertTrue(trial.waitForExistence(timeout: 5), "Billing did not load")
    }
}
