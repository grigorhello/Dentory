import XCTest

/// Count stock on the Inventory list (f18, MS-121).
final class CountStockUITests: XCTestCase {
    private let septocaine = "00000000-0000-4000-8000-0000000000d1"
    private let endoKit = "00000000-0000-4000-8000-0000000000d2"
    private let bonding = "00000000-0000-4000-8000-0000000000d4"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func stepper(_ part: String, of productID: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons["inv.count.row[\(productID)].\(part)"]
    }

    @MainActor
    private func startCounting(_ app: XCUIApplication) {
        app.buttons["Inventory"].tap()
        let countStock = app.buttons["inv.countStock"]
        XCTAssertTrue(countStock.waitForExistence(timeout: 5), "No Count stock button")
        countStock.tap()
        XCTAssertTrue(app.buttons["inv.count.cancel"].waitForExistence(timeout: 3), "Count mode did not open")
        XCTAssertEqual(app.staticTexts["inv.header.title"].label, "Count")
    }

    /// The acceptance flow: three products counted under three chips, reviewed together, applied, and the
    /// count shows on Product detail.
    @MainActor
    func testStaffCountsThreeProductsFromThreeFiltersAndApplies() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff"]
        app.launch()
        startCounting(app)

        let review = app.buttons["inv.count.review"]
        XCTAssertTrue(review.exists, "No Review button")
        XCTAssertFalse(review.isEnabled, "Review is enabled before anything changed")
        XCTAssertEqual(review.label, "Review count")
        // Pinned just above the tab bar, which stays while counting (f18).
        let gap = app.descendants(matching: .any)["tabBar"].frame.minY - review.frame.maxY
        XCTAssertGreaterThanOrEqual(gap, 0, "The tab bar covers Review")
        XCTAssertLessThan(gap, 40, "Review floats \(gap) pt above the tab bar")
        let subLine = app.staticTexts["est. 54 cartridges\u{00A0}· Operatory 1\u{00A0}· Drawer A"]
        XCTAssertTrue(subLine.exists, "The sub-line is not f18's")

        app.buttons["Low"].tap()
        XCTAssertTrue(stepper("inc", of: endoKit, in: app).waitForExistence(timeout: 3))
        stepper("inc", of: endoKit, in: app).tap()
        stepper("inc", of: endoKit, in: app).tap()
        XCTAssertEqual(app.stepperNumber("inv.count.row[\(endoKit)]"), "3")

        app.buttons["Healthy"].tap()
        XCTAssertTrue(stepper("dec", of: septocaine, in: app).waitForExistence(timeout: 3))
        stepper("dec", of: septocaine, in: app).tap()
        stepper("dec", of: septocaine, in: app).tap()
        XCTAssertEqual(app.stepperNumber("inv.count.row[\(septocaine)]"), "52")

        app.buttons["Expiring"].tap()
        let bondingLine = app.staticTexts["Count unopened only\u{00A0}· Operatory 1\u{00A0}· Drawer C"]
        XCTAssertTrue(bondingLine.waitForExistence(timeout: 3))
        stepper("inc", of: bonding, in: app).tap()
        XCTAssertEqual(app.stepperNumber("inv.count.row[\(bonding)]"), "1")

        XCTAssertEqual(review.label, "Review · 3 corrections", "A count was lost while filtering")
        review.tap()
        let reviewTitle = app.staticTexts["reviewCount.title"]
        XCTAssertTrue(reviewTitle.waitForExistence(timeout: 3), "Review corrections did not open")
        XCTAssertEqual(app.staticTexts["reviewCount.row[\(endoKit)].change"].label, "1 → 3")
        XCTAssertEqual(app.staticTexts["reviewCount.row[\(septocaine)].change"].label, "54 → 52")
        XCTAssertEqual(app.staticTexts["reviewCount.row[\(bonding)].change"].label, "0 → 1 unopened")
        let apply = app.buttons["reviewCount.apply"]
        XCTAssertEqual(apply.label, "Apply count · 3 corrections")
        apply.tap()

        XCTAssertTrue(app.staticTexts["Count applied"].waitForExistence(timeout: 5), "No toast after applying")
        XCTAssertTrue(app.staticTexts["3 products updated"].exists)
        XCTAssertEqual(app.staticTexts["inv.header.title"].label, "Inventory", "Still in count mode")
        XCTAssertTrue(app.buttons["inv.countStock"].exists)

        app.buttons["Healthy"].tap()
        let septocaineLine = app.staticTexts["52 cartridges\u{00A0}· Anesthetic"]
        XCTAssertTrue(septocaineLine.waitForExistence(timeout: 5), "The list kept 54")
        app.descendants(matching: .any)["inv.row[\(septocaine)]"].tap()
        let counted = app.staticTexts["Counted Oct 2"]
        XCTAssertTrue(counted.waitForExistence(timeout: 5), "Product detail did not show the count")
        XCTAssertTrue(app.staticTexts["54 → 52"].exists, "No Physical count row in the history")
    }

    /// Undo on a review row, Keep counting, Discard count, and Cancel without changes.
    @MainActor
    func testAdminUndoesACorrectionThenDiscardsTheCount() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        startCounting(app)
        XCTAssertFalse(app.descendants(matching: .any)["inv.newProduct"].exists, "The + button shows while counting")

        app.buttons["Low"].tap()
        XCTAssertTrue(stepper("inc", of: endoKit, in: app).waitForExistence(timeout: 3))
        stepper("inc", of: endoKit, in: app).tap()
        app.buttons["Healthy"].tap()
        XCTAssertTrue(stepper("dec", of: septocaine, in: app).waitForExistence(timeout: 3))
        stepper("dec", of: septocaine, in: app).tap()

        app.buttons["inv.count.review"].tap()
        XCTAssertTrue(app.buttons["reviewCount.row[\(endoKit)].undo"].waitForExistence(timeout: 3))
        app.buttons["reviewCount.row[\(endoKit)].undo"].tap()
        XCTAssertFalse(app.staticTexts["reviewCount.row[\(endoKit)].change"].exists, "Undo kept the row")
        XCTAssertEqual(app.buttons["reviewCount.apply"].label, "Apply count · 1 correction")
        app.buttons["reviewCount.back"].tap()
        XCTAssertEqual(app.buttons["inv.count.review"].label, "Review · 1 correction")

        app.buttons["inv.count.cancel"].tap()
        XCTAssertTrue(app.staticTexts["cancelCount.title"].waitForExistence(timeout: 3), "Cancel did not ask")
        XCTAssertEqual(app.staticTexts["cancelCount.message"].label, "1 change. Inventory stays as it is.")
        app.buttons["cancelCount.keep"].tap()
        XCTAssertEqual(app.stepperNumber("inv.count.row[\(septocaine)]"), "53", "Keep counting lost the count")

        app.buttons["inv.count.cancel"].tap()
        XCTAssertTrue(app.buttons["cancelCount.discard"].waitForExistence(timeout: 3))
        app.buttons["cancelCount.discard"].tap()
        XCTAssertTrue(app.buttons["inv.countStock"].waitForExistence(timeout: 3), "Discard did not leave count mode")
        XCTAssertTrue(app.staticTexts["54 cartridges\u{00A0}· Anesthetic"].exists, "Discard changed the stock")
        XCTAssertTrue(app.descendants(matching: .any)["inv.newProduct"].exists)

        app.buttons["inv.countStock"].tap()
        XCTAssertTrue(app.buttons["inv.count.cancel"].waitForExistence(timeout: 3))
        app.buttons["inv.count.cancel"].tap()
        XCTAssertTrue(app.buttons["inv.countStock"].waitForExistence(timeout: 3), "Cancel without changes asked")
        XCTAssertFalse(app.staticTexts["cancelCount.title"].exists)
    }
}
