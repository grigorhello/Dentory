import XCTest

/// Read-only mode (MS-142): with the trial over and no card, Home says so, every write opens the read-only sheet, and
/// an admin goes from there to Billing, the status screen.
final class ReadOnlyUITests: XCTestCase {
    private let rootCanal = "proc.template[d0000000-0000-4000-8000-000000000301]"
    private let endo = "order.row[00000000-0000-4000-8000-000000000501]"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-trial", "ended"] + arguments
        app.launch()
        return app
    }

    @MainActor
    func testAnAdminIsToldOnHomeAndAtStartAndGoesToBilling() {
        let app = launch([])
        let notice = app.staticTexts["home.notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "No notice on Home")
        XCTAssertEqual(
            notice.label,
            "Your free trial has ended. Add a card from the link in your billing email to keep updating stock."
        )
        app.buttons["home.notice.billing"].tap()
        let trial = app.descendants(matching: .any)["billing.trial"]
        XCTAssertTrue(trial.waitForExistence(timeout: 5), "Billing did not open")
        XCTAssertTrue(trial.label.contains("Trial ended"), "The card reads \(trial.label)")
        app.buttons["billing.back"].tap()

        app.buttons["tab.procedures"].tap()
        let row = app.descendants(matching: .any)[rootCanal]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No Root canal template")
        row.tap()
        let start = app.buttons["procDetail.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "Adjust, then start did not open")
        start.tap()
        XCTAssertTrue(app.staticTexts["readOnly.title"].waitForExistence(timeout: 5), "No read-only sheet")
        XCTAssertEqual(
            app.staticTexts["readOnly.message"].label,
            "You can still see everything. To make changes, add a card from the link in your billing email."
        )
        XCTAssertFalse(app.descendants(matching: .any)["toast"].exists, "Nothing started")
        app.buttons["readOnly.billing"].tap()
        XCTAssertTrue(trial.waitForExistence(timeout: 5), "Go to Billing did not open Billing")
        XCTAssertTrue(trial.label.contains("Trial ended"))
    }

    /// The clinic's data stays its own: Export CSV works in read-only mode (MS-143's decision).
    @MainActor
    func testExportStillWorksInReadOnlyMode() {
        let app = launch([])
        let account = app.buttons["home.header.account"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        account.tap()
        let export = app.buttons["more.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 5), "Account did not open")
        export.tap()
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Export CSV")
        XCTAssertTrue(toast.staticTexts["Export started"].exists)
        XCTAssertFalse(app.staticTexts["readOnly.title"].exists, "No read-only sheet for an export")
    }

    @MainActor
    func testStaffAreToldToAskTheirAdmin() {
        let app = launch(["-staff", "-tab", "toBuy"])
        let plus = app.buttons["\(endo).inc"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5), "To buy did not load")
        let value = app.staticTexts["\(endo).value"].label
        plus.tap()
        XCTAssertTrue(app.staticTexts["readOnly.title"].waitForExistence(timeout: 5), "No read-only sheet")
        XCTAssertFalse(app.buttons["readOnly.billing"].exists, "Billing is the admin's")
        app.buttons["readOnly.ok"].tap()
        XCTAssertTrue(app.staticTexts["readOnly.title"].waitForNonExistence(timeout: 5), "OK did not close it")
        XCTAssertEqual(app.staticTexts["\(endo).value"].label, value, "The quantity did not change")

        app.buttons["tab.home"].tap()
        let notice = app.staticTexts["home.notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "No notice on Home")
        XCTAssertEqual(notice.label, "Your clinic's trial has ended. Ask your admin to add a payment method.")
        XCTAssertFalse(app.buttons["home.notice.billing"].exists)
    }
}
