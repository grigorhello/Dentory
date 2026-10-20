import XCTest

/// Billing (f34, MS-100 D18) from Account: the demo clinic's trial with the lifetime promotion and its Visa card, and
/// without a card, where the link to add one goes, with no payment page in the app.
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
        let payment = app.descendants(matching: .any)["billing.paymentMethod"]
        XCTAssertTrue(payment.label.contains("Visa ·· 4242"), "The payment method reads \(payment.label)")
        XCTAssertTrue(app.buttons["billing.invoices"].label.contains("None yet"))
        XCTAssertTrue(app.buttons["billing.emails"].label.contains("owner@smiledental.ca"))
    }

    /// MS-100 D18: the app opens no payment page; it says the card is not set and where the link goes.
    @MainActor
    func testWithoutACardBillingSaysWhereTheLinkGoes() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-billingNoCard", "YES"]
        app.launch()
        openBilling(in: app)

        let payment = app.descendants(matching: .any)["billing.paymentMethod"]
        XCTAssertTrue(payment.label.contains("Not set"), "The payment method reads \(payment.label)")
        XCTAssertEqual(
            app.staticTexts["billing.paymentMethod.note"].label,
            "The link to add a card is emailed to owner@smiledental.ca."
        )
        XCTAssertFalse(app.buttons["Add"].exists, "No button leads to a payment page")
        XCTAssertFalse(app.links.firstMatch.exists, "No link leads to a payment page")
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
