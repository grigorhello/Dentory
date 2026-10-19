import XCTest

/// The Procedures tab (f11 Admin, f12 Staff, MS-122).
final class ProceduresUITests: XCTestCase {
    private let rootCanalTemplate = "proc.template[d0000000-0000-4000-8000-000000000301]"
    private let rootCanalEvent = "proc.history[00000000-0000-4000-8000-0000000000e1]"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openProcedures(_ app: XCUIApplication) {
        app.buttons["Procedures"].tap()
        XCTAssertTrue(app.staticTexts["proc.header.title"].waitForExistence(timeout: 5), "Procedures did not open")
    }

    @MainActor
    private func goBack(from identifier: String, in app: XCUIApplication) {
        app.buttons["\(identifier).back"].tap()
        XCTAssertTrue(app.staticTexts["proc.header.title"].waitForExistence(timeout: 5), "Back did not return")
    }

    @MainActor
    func testAdminSeesTemplatesShortagesAndHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openProcedures(app)

        let rootCanal = app.descendants(matching: .any)[rootCanalTemplate]
        XCTAssertTrue(rootCanal.waitForExistence(timeout: 5), "No Root canal template")
        XCTAssertTrue(app.staticTexts["1 not available"].exists, "Root canal's shortage is missing")
        XCTAssertTrue(app.staticTexts["7 items"].exists)
        let note = app.staticTexts["proc.note"]
        XCTAssertTrue(note.label.contains("Pencil edits the default supplies."), "The admin note is not f11's")
        let eyebrow = NSPredicate(format: "label ==[c] %@", "History · tap to edit usage")
        XCTAssertTrue(app.staticTexts.matching(eyebrow).firstMatch.exists, "No history eyebrow")
        let sarah = NSPredicate(format: "label BEGINSWITH %@ AND label ENDSWITH %@", "Oct 1 · 3:14", "· Sarah")
        XCTAssertTrue(app.staticTexts.matching(sarah).firstMatch.exists, "The history line is not f11's")

        rootCanal.tap()
        XCTAssertTrue(app.staticTexts["procDetail.title"].waitForExistence(timeout: 5), "The template did not open")
        XCTAssertEqual(app.staticTexts["procDetail.title"].label, "Adjust, then start")
        goBack(from: "procDetail", in: app)

        app.buttons["\(rootCanalTemplate).edit"].tap()
        XCTAssertTrue(app.staticTexts["procEdit.title"].waitForExistence(timeout: 5), "The pencil did not open")
        XCTAssertEqual(app.staticTexts["procEdit.title"].label, "Edit procedure")
        goBack(from: "procEdit", in: app)

        app.buttons["proc.addTemplate"].tap()
        XCTAssertTrue(app.staticTexts["procEdit.title"].waitForExistence(timeout: 5), "+ Procedure did not open")
        XCTAssertEqual(app.staticTexts["procEdit.title"].label, "New procedure")
        goBack(from: "procEdit", in: app)

        app.descendants(matching: .any)[rootCanalEvent].tap()
        XCTAssertTrue(app.staticTexts["procDetail.title"].waitForExistence(timeout: 5), "The history row did not open")
        XCTAssertEqual(app.staticTexts["procDetail.title"].label, "Procedure")
    }

    @MainActor
    func testStaffSeeNoTemplateControls() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff"]
        app.launch()
        openProcedures(app)

        XCTAssertTrue(app.descendants(matching: .any)[rootCanalTemplate].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["proc.addTemplate"].exists, "Staff see + Procedure")
        XCTAssertFalse(app.buttons["\(rootCanalTemplate).edit"].exists, "Staff see the pencil")
        XCTAssertEqual(
            app.staticTexts["proc.note"].label,
            "Starting a procedure deducts its supplies right away. Only an admin can add or edit procedure templates."
        )
        XCTAssertTrue(app.descendants(matching: .any)[rootCanalEvent].exists, "Staff see the history too")
    }
}
