import XCTest

/// Adjust, then start (f13, MS-123).
final class ProcedureStartUITests: XCTestCase {
    private let rootCanal = "proc.template[d0000000-0000-4000-8000-000000000301]"
    private let septocaine = "procDetail.item[00000000-0000-4000-8000-0000000000d1]"
    private let rubberDam = "procDetail.item[00000000-0000-4000-8000-0000000000d7]"
    private let disinfectant = "procDetail.bottle[00000000-0000-4000-8000-0000000000d6].takeNew"
    private let sealer = "procDetail.bottle[00000000-0000-4000-8000-0000000000d9].takeNew"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openRootCanal(_ app: XCUIApplication) {
        app.launchArguments = ["-uiTesting", "-tab", "procedures"]
        app.launch()
        let row = app.descendants(matching: .any)[rootCanal]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No Root canal template")
        row.tap()
        let summary = app.staticTexts["procDetail.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "Adjust, then start did not open")
    }

    /// The acceptance flow: Procedures → Root canal → +1 Septocaine → Start → toast.
    @MainActor
    func testStartARootCanalWithOneMoreSeptocaine() {
        let app = XCUIApplication()
        openRootCanal(app)
        XCTAssertEqual(
            app.staticTexts["procDetail.summary"].label,
            "12 supplies · 1 not available. Add or remove items before you start."
        )
        XCTAssertEqual(app.staticTexts["\(rubberDam).warning"].label, "Not available · 0 in stock")
        let start = app.buttons["procDetail.start"]
        XCTAssertEqual(start.label, "Start procedure · 10 items")

        app.buttons["\(septocaine).inc"].tap()
        XCTAssertEqual(app.staticTexts["\(septocaine).value"].label, "3")
        XCTAssertEqual(start.label, "Start procedure · 11 items")
        start.tap()

        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Start")
        XCTAssertTrue(toast.staticTexts["Root canal started"].exists)
        XCTAssertTrue(toast.staticTexts["11 items deducted"].exists)
        XCTAssertTrue(app.staticTexts["proc.header.title"].waitForExistence(timeout: 5), "Start did not return")
    }

    /// Take new, Out of stock, Add item and the X.
    @MainActor
    func testTakeNewAddItemAndRemove() {
        let app = XCUIApplication()
        openRootCanal(app)
        let start = app.buttons["procDetail.start"]

        app.swipeUp()
        let takeNew = app.buttons[disinfectant]
        XCTAssertTrue(takeNew.waitForExistence(timeout: 3))
        takeNew.tap()
        XCTAssertEqual(start.label, "Start procedure · 11 items", "Take new did not count one item")
        let willTake = NSPredicate(format: "label BEGINSWITH %@", "Will take 1 from stock")
        XCTAssertTrue(app.staticTexts.matching(willTake).firstMatch.exists, "The bottle line did not change")

        app.buttons[sealer].tap()
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 3), "No Out of stock toast")
        XCTAssertTrue(toast.staticTexts["Out of stock"].exists)
        XCTAssertEqual(start.label, "Start procedure · 11 items", "Out of stock changed the count")

        app.buttons["procDetail.addItem"].tap()
        XCTAssertTrue(app.staticTexts["addItem.title"].waitForExistence(timeout: 3), "Add item did not open")
        let gauze = app.buttons["addItem.row[00000000-0000-4000-8000-000000000208].add"]
        XCTAssertTrue(gauze.waitForExistence(timeout: 5), "Gauze is not offered")
        gauze.tap()
        XCTAssertFalse(app.staticTexts["addItem.title"].waitForExistence(timeout: 2), "The sheet did not close")
        XCTAssertEqual(start.label, "Start procedure · 12 items", "Gauze was not added with 1")

        app.buttons["\(rubberDam).remove"].tap()
        XCTAssertEqual(start.label, "Start procedure · 11 items", "The X did not remove Rubber dam")
        XCTAssertFalse(app.staticTexts["\(rubberDam).warning"].exists)
    }

    /// Add item offers a multi-use product outside the template and takes a new one for this procedure.
    @MainActor
    func testAddingAMultiUseProductTakesANewOne() {
        let app = XCUIApplication()
        openRootCanal(app)
        let start = app.buttons["procDetail.start"]
        app.swipeUp()
        app.buttons["procDetail.addItem"].tap()
        XCTAssertTrue(app.staticTexts["addItem.title"].waitForExistence(timeout: 3), "Add item did not open")
        let composite = app.buttons["addItem.row[00000000-0000-4000-8000-0000000000d3].add"]
        XCTAssertTrue(composite.waitForExistence(timeout: 5), "Composite A2 is not offered")
        XCTAssertTrue(app.staticTexts["1 unopened · 1 open"].exists, "The multi-use caption is off")
        composite.tap()
        XCTAssertFalse(app.staticTexts["addItem.title"].waitForExistence(timeout: 2), "The sheet did not close")
        XCTAssertEqual(start.label, "Start procedure · 11 items", "Composite A2 was not taken new")
        XCTAssertEqual(app.staticTexts["procDetail.item[00000000-0000-4000-8000-0000000000d3].value"].label, "1")
    }
}
