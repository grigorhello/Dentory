import XCTest

/// A past procedure (f14, MS-124): the record, Edit usage, Discard and Cancel procedure.
final class ProcedureEventUITests: XCTestCase {
    private let rootCanal = "proc.history[00000000-0000-4000-8000-0000000000e1]"
    private let septocaine = "procDetail.item[00000000-0000-4000-8000-0000000000d1]"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openRootCanal(_ app: XCUIApplication) {
        app.launchArguments = ["-uiTesting", "-tab", "procedures"]
        app.launch()
        let row = app.descendants(matching: .any)[rootCanal]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No Root canal in the history")
        row.tap()
        XCTAssertTrue(app.staticTexts["procDetail.summary"].waitForExistence(timeout: 5), "The record did not open")
    }

    /// The acceptance flow: History → Root canal → Edit usage → +1 Septocaine → Save changes → "Usage updated".
    @MainActor
    func testEditUsageSavesTheNewQuantity() {
        let app = XCUIApplication()
        openRootCanal(app)
        let recorded = app.staticTexts["procDetail.summary"].label
        XCTAssertEqual(recorded, "10 items deducted · Oct 1 · 3:14\u{202F}PM · Sarah")
        app.buttons["procDetail.editUsage"].tap()

        XCTAssertTrue(app.staticTexts["procDetail.editing"].waitForExistence(timeout: 3), "Editing did not start")
        let save = app.buttons["procDetail.save"]
        XCTAssertFalse(save.isEnabled, "Save changes is enabled before anything changed")
        app.buttons["\(septocaine).inc"].tap()
        XCTAssertEqual(app.staticTexts["\(septocaine).value"].label, "3")
        XCTAssertEqual(app.staticTexts["\(septocaine).warning"].label, "Recorded 2")
        save.tap()

        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Save changes")
        XCTAssertTrue(toast.staticTexts["Usage updated"].exists)
        let summary = app.staticTexts["procDetail.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "Save did not end editing")
        XCTAssertEqual(summary.label, "11 items deducted · Oct 1 · 3:14\u{202F}PM · Sarah")
    }

    /// Cancel procedure waits for a note, then goes back with the items returned.
    @MainActor
    func testCancelNeedsANoteAndReturnsTheItems() {
        let app = XCUIApplication()
        openRootCanal(app)
        app.buttons["procDetail.cancel"].tap()

        let warning = app.staticTexts["cancelProcedure.warning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 3), "The cancel sheet did not open")
        XCTAssertEqual(warning.label, "10 items will be returned to inventory. Stock levels update immediately.")
        let confirm = app.buttons["cancelProcedure.confirm"]
        XCTAssertFalse(confirm.isEnabled, "Cancel procedure is enabled without a note")
        let note = app.textFields["cancelProcedure.note"]
        note.tap()
        note.typeText("Logged by mistake")
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()

        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Cancel procedure")
        XCTAssertTrue(toast.staticTexts["Root canal cancelled"].exists)
        XCTAssertTrue(toast.staticTexts["10 items returned"].exists)
        XCTAssertTrue(app.staticTexts["proc.header.title"].waitForExistence(timeout: 5), "Cancel did not go back")
    }

    /// Home's Edit usage opens the latest procedure in editing; Discard leaves the record as it was.
    @MainActor
    func testHomeEditUsageOpensEditingAndDiscardKeepsTheRecord() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let editUsage = app.descendants(matching: .any)["home.procedure.editUsage"]
        XCTAssertTrue(editUsage.waitForExistence(timeout: 5), "Home has no Edit usage")
        editUsage.tap()

        XCTAssertTrue(app.staticTexts["procDetail.editing"].waitForExistence(timeout: 5), "Editing did not open")
        app.buttons["\(septocaine).dec"].tap()
        XCTAssertEqual(app.staticTexts["\(septocaine).value"].label, "1")
        app.buttons["procDetail.discard"].tap()
        let summary = app.staticTexts["procDetail.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 3), "Discard did not end editing")
        XCTAssertEqual(summary.label, "10 items deducted · Oct 1 · 3:14\u{202F}PM · Sarah")
        app.buttons["procDetail.back"].tap()
        XCTAssertTrue(app.staticTexts["Smile Dental"].waitForExistence(timeout: 5), "Back did not return Home")
    }
}
