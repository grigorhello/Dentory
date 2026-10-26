import XCTest

/// Start procedure with Take new → Edit usage → Cancel procedure (MS-136), on the demo clinic's Cleaning: the start
/// takes a new Fluoride varnish and deducts the supplies through `stock_procedure_start`, Edit usage on Home's procedure
/// card, which now shows the procedure just started, raises the gloves through `stock_procedure_edit`, and Cancel
/// procedure gives everything back through `stock_procedure_cancel`, the varnish unopened, as Inventory shows after
/// each step.
final class ProcedureE2ETests: XCTestCase {
    private let gloves = E2E.product(5)
    private let fluorideVarnish = E2E.product(14)

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testACleaningIsStartedWithANewVarnishEditedThenCancelled() {
        let app = E2E.signedIn(E2E.admin)
        expectStock("14 boxes", "2 unopened\u{00A0}· 1 open", "before the procedure", in: app)

        app.buttons["tab.procedures"].tap()
        let cleaning = app.descendants(matching: .any)["proc.template[\(E2E.template(2))]"]
        cleaning.appears("No Cleaning template")
        cleaning.tap()
        let start = app.buttons["procDetail.start"]
        start.appears("Adjust, then start did not open")
        E2E.expect(start, toRead: "Start procedure · 5 items", "The Cleaning's supplies")
        let takeNew = app.buttons["procDetail.bottle[\(fluorideVarnish)].takeNew"]
        if !takeNew.isHittable { app.swipeUp() }
        takeNew.tap()
        E2E.expect(start, toRead: "Start procedure · 6 items", "Take new did not count the varnish")
        start.tap()
        E2E.expectToast("Cleaning started", "6 items deducted", in: app)
        expectStock("12 boxes", "1 unopened\u{00A0}· 2 open", "after the start", in: app)

        // Home reloads as its tab is chosen: its card shows the Cleaning just started, and Edit usage opens it.
        app.buttons["tab.home"].tap()
        let latest = app.descendants(matching: .any)["home.procedure.latest"]
        latest.appears("Home has no latest procedure")
        E2E.expect(latest, toRead: "Cleaning", "Home's card does not show the procedure just started")
        E2E.expect(latest, toRead: "6 supplies\u{00A0}· Sarah", "Home's card does not count the start's supplies")
        app.buttons["home.procedure.editUsage"].tap()
        app.staticTexts["procDetail.editing"].appears("Edit usage did not open the procedure")
        app.buttons["procDetail.item[\(gloves)].inc"].tap()
        XCTAssertEqual(app.staticTexts["procDetail.item[\(gloves)].value"].label, "3")
        app.buttons["procDetail.save"].tap()
        let toast = app.descendants(matching: .any)["toast"]
        toast.appears("No toast after Save changes")
        XCTAssertTrue(toast.staticTexts["Usage updated"].exists)
        let summary = app.staticTexts["procDetail.summary"]
        E2E.expect(summary, toRead: "7 items deducted", "The record does not show the extra box")

        app.buttons["procDetail.cancel"].tap()
        let note = app.textFields["cancelProcedure.note"]
        note.appears("The cancel sheet did not open")
        XCTAssertEqual(
            app.staticTexts["cancelProcedure.warning"].label,
            "7 items will be returned to inventory. Stock levels update immediately."
        )
        note.tap()
        note.typeText("Logged by mistake")
        app.buttons["cancelProcedure.confirm"].tap()
        E2E.expectToast("Cleaning cancelled", "7 items returned", in: app)
        // The varnish opened for the procedure goes back unopened.
        expectStock("14 boxes", "2 unopened\u{00A0}· 1 open", "after the cancellation", in: app)
    }

    /// The gloves and the varnish on Inventory, which reloads as its tab is chosen.
    @MainActor
    private func expectStock(_ gloveBoxes: String, _ varnish: String, _ moment: String, in app: XCUIApplication) {
        app.buttons["tab.inventory"].tap()
        E2E.expect(E2E.inventoryRow(gloves, searching: "Nitrile", in: app), toRead: gloveBoxes, "Gloves \(moment)")
        let varnishRow = E2E.inventoryRow(fluorideVarnish, searching: "Fluoride", in: app)
        E2E.expect(varnishRow, toRead: varnish, "Fluoride varnish \(moment)")
    }
}
