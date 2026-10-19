import XCTest

/// Edit procedure and New procedure (f15, MS-125), Admin.
final class ProcedureEditUITests: XCTestCase {
    private let rootCanal = "proc.template[d0000000-0000-4000-8000-000000000301]"
    private let septocaine = "procEdit.item[00000000-0000-4000-8000-0000000000d1]"
    private let rubberDam = "procEdit.item[00000000-0000-4000-8000-0000000000d7]"
    private let disinfectant = "procEdit.item[00000000-0000-4000-8000-0000000000d6]"
    private let gauze = "addItem.row[00000000-0000-4000-8000-000000000208].add"
    private let composite = "addItem.row[00000000-0000-4000-8000-0000000000d3].add"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-tab", "procedures"]
        app.launch()
        return app
    }

    @MainActor
    private func openRootCanal(_ app: XCUIApplication) {
        let pencil = app.buttons["\(rootCanal).edit"]
        XCTAssertTrue(pencil.waitForExistence(timeout: 5), "No pencil on Root canal")
        pencil.tap()
        XCTAssertTrue(app.buttons["\(septocaine).inc"].waitForExistence(timeout: 5), "Edit procedure did not load")
    }

    @MainActor
    private func expectToast(_ title: String, _ detail: String, in app: XCUIApplication) {
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast")
        XCTAssertTrue(toast.staticTexts[title].exists, "The toast does not say \(title)")
        XCTAssertTrue(toast.staticTexts[detail].exists, "The toast does not say \(detail)")
        XCTAssertTrue(app.staticTexts["proc.header.title"].waitForExistence(timeout: 5), "Not back on Procedures")
    }

    /// The acceptance flow: the defaults of Root canal change, a supply goes, Gauze joins, and Save goes back.
    @MainActor
    func testEditTheDefaultsOfRootCanal() {
        let app = launch()
        openRootCanal(app)
        XCTAssertEqual(app.staticTexts["procEdit.title"].label, "Edit procedure")
        XCTAssertEqual(app.textFields["procEdit.name"].value as? String, "Root canal")
        XCTAssertTrue(app.buttons["procEdit.save"].exists, "No Save in the header")

        XCTAssertEqual(app.staticTexts["\(septocaine).value"].label, "2")
        app.buttons["\(septocaine).inc"].tap()
        XCTAssertEqual(app.staticTexts["\(septocaine).value"].label, "3")
        app.buttons["\(septocaine).dec"].tap()
        app.buttons["\(septocaine).dec"].tap()
        XCTAssertEqual(app.staticTexts["\(septocaine).value"].label, "1")
        XCTAssertFalse(app.buttons["\(septocaine).dec"].isEnabled, "A default can go under 1")

        app.buttons["\(rubberDam).remove"].tap()
        XCTAssertFalse(app.buttons["\(rubberDam).inc"].exists, "The X did not remove Rubber dam")

        app.swipeUp()
        XCTAssertEqual(
            app.staticTexts["\(disinfectant).caption"].label, "Multi-use · listed under Opened a new one?"
        )
        XCTAssertFalse(app.buttons["\(disinfectant).inc"].exists, "A multi-use supply has a stepper")
        XCTAssertTrue(app.staticTexts["procEdit.note"].exists)

        app.buttons["procEdit.addItem"].tap()
        XCTAssertTrue(app.buttons[gauze].waitForExistence(timeout: 5), "Gauze is not offered")
        XCTAssertTrue(
            app.otherElements["addItem"].staticTexts["Surgical"].firstMatch.exists, "Add item shows no category"
        )
        app.buttons[gauze].tap()
        XCTAssertFalse(app.staticTexts["addItem.title"].waitForExistence(timeout: 2), "The sheet did not close")
        XCTAssertEqual(app.staticTexts["procEdit.item[00000000-0000-4000-8000-000000000208].value"].label, "1")

        app.buttons["procEdit.save"].tap()
        expectToast("Procedure saved", "Root canal · 12 default supplies", in: app)
    }

    /// "+ Procedure": an empty template, a multi-use product added at 0, and no name saves as Untitled procedure.
    @MainActor
    func testANewProcedureWithoutANameIsUntitled() {
        let app = launch()
        let add = app.buttons["proc.addTemplate"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "No + Procedure")
        add.tap()
        XCTAssertTrue(app.staticTexts["procEdit.title"].waitForExistence(timeout: 5), "New procedure did not open")
        XCTAssertEqual(app.staticTexts["procEdit.title"].label, "New procedure")
        XCTAssertTrue(app.staticTexts["procEdit.empty"].exists, "No 'No supplies yet.'")
        XCTAssertFalse(app.buttons["procEdit.delete"].exists, "A new procedure offers Delete")

        app.buttons["procEdit.addItem"].tap()
        XCTAssertTrue(app.buttons[composite].waitForExistence(timeout: 5), "Composite A2 is not offered")
        XCTAssertTrue(app.otherElements["addItem"].staticTexts["Restorative · multi-use"].firstMatch.exists)
        app.buttons[composite].tap()
        XCTAssertFalse(app.staticTexts["addItem.title"].waitForExistence(timeout: 2), "The sheet did not close")
        XCTAssertEqual(
            app.staticTexts["procEdit.item[00000000-0000-4000-8000-0000000000d3].caption"].label,
            "Multi-use · listed under Opened a new one?"
        )

        app.buttons["procEdit.save"].tap()
        expectToast("Procedure saved", "Untitled procedure · 1 default supply", in: app)
    }

    /// Delete procedure: Keep closes the sheet; Delete archives the template and goes back.
    @MainActor
    func testDeleteAProcedure() {
        let app = launch()
        openRootCanal(app)
        app.swipeUp()
        app.swipeUp()
        let delete = app.buttons["procEdit.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3), "No Delete procedure")
        delete.tap()
        XCTAssertTrue(app.staticTexts["deleteProcedure.title"].waitForExistence(timeout: 3), "The sheet did not open")
        XCTAssertEqual(app.staticTexts["deleteProcedure.title"].label, "Delete Root canal?")
        XCTAssertEqual(app.staticTexts["deleteProcedure.message"].label, "Past procedures keep their data.")
        app.buttons["deleteProcedure.keep"].tap()
        XCTAssertFalse(app.staticTexts["deleteProcedure.title"].waitForExistence(timeout: 2), "Keep did not close it")

        delete.tap()
        XCTAssertTrue(app.buttons["deleteProcedure.confirm"].waitForExistence(timeout: 3))
        app.buttons["deleteProcedure.confirm"].tap()
        expectToast("Procedure deleted", "Root canal", in: app)
    }
}
