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

    /// At the largest text size before the accessibility sizes, the price row stacks and stays on the screen.
    @MainActor
    func testThePriceRowStaysOnScreenAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
        app.launch()
        openBilling(in: app)

        let price = app.descendants(matching: .any)["billing.price"]
        let screen = app.windows.firstMatch.frame
        XCTAssertTrue(price.label.contains("$49.50 / month"), "The price reads \(price.label)")
        XCTAssertGreaterThanOrEqual(price.frame.minX, screen.minX, "The price row starts off screen")
        XCTAssertLessThanOrEqual(price.frame.maxX, screen.maxX, "The price row runs off screen")
    }

    /// f35: before the first charge, Invoices says when it comes (MS-141).
    @MainActor
    func testInvoicesAreEmptyUntilTheTrialEnds() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openBilling(in: app)

        app.buttons["billing.invoices"].tap()
        let empty = app.descendants(matching: .any)["invoices.empty"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5), "Invoices did not open")
        XCTAssertTrue(empty.label.contains("No invoices yet"), "The empty state reads \(empty.label)")
        XCTAssertTrue(empty.label.contains("when the trial ends on January 6, 2027"), "It reads \(empty.label)")
    }

    @MainActor
    func testInvoicesShowTheirAmountAndStatusWithoutLinks() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-billingInvoices", "YES"]
        app.launch()
        openBilling(in: app)

        XCTAssertTrue(app.buttons["billing.invoices"].label.contains("3"), "Billing counts them")
        app.buttons["billing.invoices"].tap()
        let latest = app.descendants(matching: .any)["invoices.row[00000000-0000-4000-8000-000000000900]"]
        XCTAssertTrue(latest.waitForExistence(timeout: 5), "No invoice rows")
        XCTAssertTrue(latest.label.contains("Mar 9, 2027"), "The row reads \(latest.label)")
        XCTAssertTrue(latest.label.contains("$49.50"), "The row reads \(latest.label)")
        XCTAssertTrue(latest.label.contains("Open"), "The row reads \(latest.label)")
        XCTAssertFalse(app.links.firstMatch.exists, "No invoice links anywhere (MS-100 D18)")
    }

    /// The billing emails sheet: the primary stays, another address is added, Done says so (MS-141).
    @MainActor
    func testAnAdminAddsABillingEmail() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openBilling(in: app)

        app.buttons["billing.emails"].tap()
        XCTAssertTrue(app.staticTexts["billingEmails.title"].waitForExistence(timeout: 5), "No billing emails sheet")
        let primary = app.descendants(matching: .any)["billingEmails.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 5))
        XCTAssertTrue(primary.label.contains("owner@smiledental.ca"), "The primary reads \(primary.label)")
        XCTAssertFalse(app.buttons["billingEmails.remove[owner@smiledental.ca]"].exists, "The primary has no X")
        let field = app.textFields["billingEmails.email"]
        field.tap()
        field.typeText("books@smiledental.ca")
        app.buttons["billingEmails.add"].tap()
        XCTAssertTrue(app.buttons["billingEmails.remove[books@smiledental.ca]"].waitForExistence(timeout: 5))
        app.buttons["billingEmails.done"].tap()
        XCTAssertTrue(app.staticTexts["Billing emails updated"].waitForExistence(timeout: 5), "No toast")
        XCTAssertTrue(app.buttons["billing.emails"].label.contains("owner@smiledental.ca"), "The primary still leads")
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
