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

    /// The entry points of screens still to come are gated too: Count stock opens the sheet (MS-142 review).
    @MainActor
    func testCountStockOpensTheSheet() {
        let app = launch(["-tab", "inventory"])
        let count = app.buttons["inv.countStock"]
        XCTAssertTrue(count.waitForExistence(timeout: 5), "Inventory did not load")
        count.tap()
        XCTAssertTrue(app.staticTexts["readOnly.title"].waitForExistence(timeout: 5), "No read-only sheet")
        app.buttons["readOnly.ok"].tap()
        XCTAssertTrue(app.staticTexts["readOnly.title"].waitForNonExistence(timeout: 5))
        app.buttons["inv.newProduct"].tap()
        XCTAssertTrue(app.staticTexts["readOnly.title"].waitForExistence(timeout: 5), "New product is not gated")
        XCTAssertFalse(app.staticTexts["newProduct.title"].exists, "The New product sheet opened")
    }

    /// Product detail's Edit and Delete product open the read-only sheet instead of theirs (MS-117).
    @MainActor
    func testProductEditAndDeleteOpenTheSheet() {
        let app = launch(["-tab", "inventory"])
        let row = app.descendants(matching: .any)["inv.row[00000000-0000-4000-8000-0000000000d1]"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The Septocaine row is missing")
        row.tap()
        let edit = app.buttons["product.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "Product detail did not open")
        edit.tap()
        XCTAssertTrue(app.staticTexts["readOnly.title"].waitForExistence(timeout: 5), "Edit is not gated")
        XCTAssertFalse(app.staticTexts["newProduct.title"].exists, "The Edit sheet opened")
        app.buttons["readOnly.ok"].tap()
        XCTAssertTrue(app.staticTexts["readOnly.title"].waitForNonExistence(timeout: 5))
        app.swipeUp()
        let delete = app.descendants(matching: .any)["product.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3), "No Delete product")
        delete.tap()
        XCTAssertTrue(app.staticTexts["readOnly.title"].waitForExistence(timeout: 5), "Delete product is not gated")
        XCTAssertFalse(app.staticTexts["deleteProduct.title"].exists, "The Delete sheet opened")
    }

    /// Clinic settings' Save opens the sheet once Clinic settings (MS-139) is in.
    @MainActor
    func testClinicSettingsSaveOpensTheSheet() {
        let app = launch([])
        let account = app.buttons["home.header.account"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        account.tap()
        let settings = app.buttons["more.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "Account did not open")
        settings.tap()
        if !app.staticTexts["settings.title"].waitForExistence(timeout: 2) { settings.tap() }
        let digest = app.descendants(matching: .any)["settings.digest"]
        XCTAssertTrue(digest.waitForExistence(timeout: 5), "Clinic settings did not load")
        digest.tap()
        app.buttons["settings.save"].tap()
        XCTAssertTrue(app.staticTexts["readOnly.title"].waitForExistence(timeout: 5), "No read-only sheet")
        XCTAssertFalse(app.staticTexts["Settings saved"].exists, "Nothing saved")
    }

    /// Taking someone off the team stays open in read-only mode, since removing access must not wait for billing; a new
    /// role still opens the read-only sheet (MS-142 follow-up).
    @MainActor
    func testAnAdminStillRemovesATeammateButCannotChangeARole() {
        let daniel = "team.member[00000000-0000-4000-8000-0000000000a2]"
        let app = launch([])
        let account = app.buttons["home.header.account"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        account.tap()
        let team = app.buttons["more.team"]
        XCTAssertTrue(team.waitForExistence(timeout: 5), "Account did not open")
        team.tap()
        if !app.staticTexts["team.title"].waitForExistence(timeout: 2) { team.tap() }
        let row = app.buttons[daniel]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The team did not load")
        row.tap()
        let role = app.buttons["\(daniel).menu.role"]
        XCTAssertTrue(role.waitForExistence(timeout: 5), "No menu")
        role.tap()
        XCTAssertTrue(app.staticTexts["readOnly.title"].waitForExistence(timeout: 5), "Change role is not gated")
        app.buttons["readOnly.ok"].tap()
        XCTAssertTrue(app.staticTexts["readOnly.title"].waitForNonExistence(timeout: 5))
        row.tap()
        let remove = app.buttons["\(daniel).menu.remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "No menu")
        remove.tap()
        let confirm = app.buttons["team.remove.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No question before removing")
        confirm.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "Remove did not work in read-only mode")
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
