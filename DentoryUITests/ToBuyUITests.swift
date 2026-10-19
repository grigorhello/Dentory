import XCTest

/// To buy (f25 Admin, f26 Staff, MS-128).
final class ToBuyUITests: XCTestCase {
    private let endo = "order.row[00000000-0000-4000-8000-000000000501]"
    private let composite = "order.row[00000000-0000-4000-8000-000000000502]"
    private let rubberDam = "order.row[00000000-0000-4000-8000-000000000503]"
    private let gauze = "addOrder.row[00000000-0000-4000-8000-000000000208].add"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(staff: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-tab", "toBuy"] + (staff ? ["-staff"] : [])
        app.launch()
        XCTAssertTrue(app.buttons["\(endo).inc"].waitForExistence(timeout: 5), "To buy did not load")
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The acceptance flow on the admin's list: the segments and selection of f25, a quantity, Clear and Select all,
    /// and Mark N as ordered moving the lines to Ordered.
    @MainActor
    func testAdminMarksTheSelectedLinesAsOrdered() {
        let app = launch()
        XCTAssertTrue(app.buttons["To buy · 3"].exists, "The segments do not count the lines")
        XCTAssertTrue(app.buttons["Ordered · 5"].exists)
        XCTAssertEqual(app.staticTexts["order.selectionBar.summary"].label, "3 of 3 selected")
        let markOrdered = app.buttons["order.markOrdered"]
        XCTAssertEqual(markOrdered.label, "Mark 3 as ordered")
        XCTAssertEqual(app.staticTexts["\(endo).value"].label, "4")

        app.buttons["\(endo).inc"].tap()
        XCTAssertEqual(app.staticTexts["\(endo).value"].label, "5")

        app.buttons["order.selectionBar.toggle"].tap()
        XCTAssertEqual(app.staticTexts["order.selectionBar.summary"].label, "0 of 3 selected")
        XCTAssertFalse(markOrdered.isEnabled, "Mark as ordered works with nothing selected")
        app.buttons["order.selectionBar.toggle"].tap()
        // A tap 2 pt inside the leading edge of the 44 pt target, in the card's padding, still lands (PRD §7).
        let checkbox = element("\(rubberDam).select", in: app)
        checkbox.coordinate(withNormalizedOffset: CGVector(dx: 2 / checkbox.frame.width, dy: 0.5)).tap()
        XCTAssertEqual(markOrdered.label, "Mark 2 as ordered")

        markOrdered.tap()
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast")
        XCTAssertTrue(toast.staticTexts["Marked as ordered"].exists)
        XCTAssertTrue(toast.staticTexts["2 items"].exists)
        XCTAssertTrue(app.buttons["To buy · 1"].waitForExistence(timeout: 3), "The lines did not leave To buy")
        app.buttons["Ordered · 7"].tap()
        XCTAssertTrue(
            element("order.ordered[00000000-0000-4000-8000-000000000501]", in: app).waitForExistence(timeout: 3),
            "Endo file kit is not under Ordered"
        )
    }

    /// Add item, its Undo, and the swipe that removes a line.
    @MainActor
    func testAddItemAndSwipeToRemove() {
        let app = launch()
        app.buttons["order.add"].tap()
        XCTAssertTrue(app.staticTexts["addOrder.title"].waitForExistence(timeout: 3), "Add to To buy did not open")
        let add = app.buttons[gauze]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Gauze is not offered")
        add.tap()
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast")
        XCTAssertTrue(toast.staticTexts["Added to To buy"].exists)
        XCTAssertTrue(toast.staticTexts["Gauze · suggested 2 packs"].exists)
        XCTAssertTrue(app.buttons["To buy · 4"].waitForExistence(timeout: 3), "Gauze was not added")
        app.buttons["toast.undo"].tap()
        XCTAssertTrue(app.buttons["To buy · 3"].waitForExistence(timeout: 3), "Undo did not take Gauze off")

        // A drag across the row: XCUITest's swipeLeft on a small element moves too little to open it.
        let start = app.staticTexts["\(composite).value"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -220, dy: 0)))
        let remove = app.buttons["\(composite).remove"]
        let revealed = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: remove)
        wait(for: [revealed], timeout: 3)
        remove.tap()
        XCTAssertTrue(app.buttons["To buy · 2"].waitForExistence(timeout: 3), "Remove did not take the line off")
        XCTAssertFalse(app.buttons["\(composite).inc"].exists)
    }

    /// Staff change quantities and add items but see no checkboxes, no selection bar and no Mark as ordered (f26).
    @MainActor
    func testStaffSeeNoOrdering() {
        let app = launch(staff: true)
        XCTAssertFalse(element("\(endo).select", in: app).exists, "Staff see a checkbox")
        XCTAssertFalse(element("order.selectionBar", in: app).exists, "Staff see the selection bar")
        XCTAssertFalse(app.buttons["order.markOrdered"].exists, "Staff see Mark as ordered")
        app.buttons["\(endo).inc"].tap()
        XCTAssertEqual(app.staticTexts["\(endo).value"].label, "5")
        XCTAssertTrue(app.buttons["order.add"].exists)
    }
}
