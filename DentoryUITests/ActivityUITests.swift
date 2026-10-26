import XCTest

/// Activity (f8, MS-133): the bell, the alerts, where one leads, and the dot that clears once they are seen.
final class ActivityUITests: XCTestCase {
    private let rubberDam = "activity.alert[00000000-0000-4000-8000-000000000701]"

    override func setUp() {
        continueAfterFailure = false
    }

    /// The acceptance flow: bell with its dot → f8's three alerts → Rubber dam opens its product → back to Home, and
    /// the bell has no dot any more.
    @MainActor
    func testTheBellOpensTheAlertsAndLosesItsDot() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let bell = app.buttons["home.header.bell"]
        XCTAssertTrue(bell.waitForExistence(timeout: 5), "No bell")
        XCTAssertEqual(bell.value as? String, "New alerts", "The bell has no dot")
        bell.tap()

        XCTAssertTrue(app.buttons["Alerts · 3"].waitForExistence(timeout: 5), "Activity did not open on Alerts")
        let row = app.buttons[rubberDam]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No Rubber dam alert")
        XCTAssertTrue(row.label.contains("Rubber dam latex-free is out of stock."), "Row reads \(row.label)")
        XCTAssertTrue(app.staticTexts["Bonding agent expires in 59 days."].exists)
        XCTAssertTrue(app.staticTexts["Gutta percha F2 is missing expiry information."].exists)

        row.tap()
        let title = app.staticTexts["product.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "The alert did not open its product")
        XCTAssertEqual(title.label, "Rubber dam latex-free")

        app.buttons["product.back"].tap()
        XCTAssertTrue(app.buttons["activity.back"].waitForExistence(timeout: 5))
        app.buttons["activity.back"].tap()
        let noDot = NSPredicate(format: "value == ''")
        wait(for: [expectation(for: noDot, evaluatedWith: bell)], timeout: 5)
    }

    /// History (f9, MS-134): the demo's changes by day, a chip that narrows them, and the alerts still a tap away.
    @MainActor
    func testHistoryListsTheChangesByDayAndFilters() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff"]
        app.launch()

        let bell = app.buttons["home.header.bell"]
        XCTAssertTrue(bell.waitForExistence(timeout: 5))
        bell.tap()
        XCTAssertTrue(app.buttons["History"].waitForExistence(timeout: 5))
        app.buttons["History"].tap()

        let rootCanal = row(0xe1, in: app)
        XCTAssertTrue(rootCanal.waitForExistence(timeout: 5), "No Root canal row")
        for text in ["Root canal", "Procedure started", "Sarah\u{00A0}· 3:14\u{202F}PM", "\u{2212}10"] {
            XCTAssertTrue(rootCanal.label.contains(text), "The row reads \(rootCanal.label)")
        }
        let firstDay = app.descendants(matching: .any).matching(identifier: "activity.day").firstMatch
        XCTAssertEqual(firstDay.label.lowercased(), "yesterday")

        app.buttons["Counts"].tap()
        let count = row(0xf1, in: app)
        XCTAssertTrue(count.waitForExistence(timeout: 5), "Counts lists no count")
        XCTAssertTrue(count.label.contains("43 → 41"), "The count reads \(count.label)")
        XCTAssertTrue(rootCanal.waitForNonExistence(timeout: 3), "Counts still lists a procedure")

        app.buttons["Alerts · 3"].tap()
        XCTAssertTrue(app.buttons[rubberDam].waitForExistence(timeout: 3), "Staff see the alerts too")
    }

    /// Product detail's Show all opens that product's history, each procedure with the product's own quantity.
    @MainActor
    func testShowAllOpensTheProductsHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-tab", "inventory"]
        app.launch()

        let septocaine = app.buttons["inv.row[00000000-0000-4000-8000-0000000000d1]"]
        XCTAssertTrue(septocaine.waitForExistence(timeout: 5), "The Septocaine row is missing")
        septocaine.tap()
        let showAll = app.buttons["product.historyAll"]
        XCTAssertTrue(showAll.waitForExistence(timeout: 5), "No Show all")
        showAll.tap()
        XCTAssertTrue(app.staticTexts["activity.title"].waitForExistence(timeout: 5), "History did not open")
        XCTAssertEqual(app.staticTexts["activity.title"].label, "History")
        XCTAssertEqual(app.staticTexts["activity.subtitle"].label, "Septocaine 4% 1:100,000")
        let procedure = row(0xf2, in: app)
        XCTAssertTrue(procedure.waitForExistence(timeout: 5), "No Root canal row")
        XCTAssertTrue(procedure.label.contains("Root canal"), "The row reads \(procedure.label)")
        XCTAssertTrue(procedure.label.contains("\u{2212}2"), "The row reads \(procedure.label)")
    }

    /// More than a page (MS-134 review): the oldest rows appear only once scrolled to, and a second visit, which starts
    /// from the cached first page, still pages.
    @MainActor
    func testHistoryPagesAsItScrolls() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoHistoryRows", "120"]
        app.launch()
        let newest = row(0xe1, in: app)
        let oldest = row(0x9000 + 119, in: app)

        openHistory(in: app)
        XCTAssertTrue(newest.waitForExistence(timeout: 5), "No first page")
        XCTAssertFalse(oldest.exists, "The last page loaded before any scrolling")
        scroll(app, until: oldest)
        XCTAssertTrue(oldest.exists, "Scrolling did not reach the last page")

        app.buttons["activity.back"].tap()
        openHistory(in: app)
        XCTAssertTrue(newest.waitForExistence(timeout: 5), "No first page on the second visit")
        XCTAssertFalse(oldest.exists, "The second visit loaded every page at once")
        scroll(app, until: oldest)
        XCTAssertTrue(oldest.exists, "The second visit did not page")
    }

    /// The header, the segments and History's chips stay pinned while the days scroll under them (f09-2), so Back,
    /// Alerts and the chips are always in reach, and a chip still filters from the scrolled list.
    @MainActor
    func testTheSegmentsAndChipsStayPinnedWhileHistoryScrolls() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoHistoryRows", "120"]
        app.launch()
        openHistory(in: app)
        let newest = row(0xe1, in: app)
        XCTAssertTrue(newest.waitForExistence(timeout: 5), "No first page")
        let pinned = PinnedElements([
            ("Back", app.buttons["activity.back"]), ("The segments", app.buttons["Alerts · 3"]),
            ("The chips", app.buttons["Counts"])
        ])

        app.swipeUp()
        app.swipeUp()
        XCTAssertFalse(newest.exists && newest.isHittable, "History did not scroll")
        pinned.assertInReach()
        app.buttons["Counts"].tap()
        XCTAssertTrue(row(0xf1, in: app).waitForExistence(timeout: 5), "Counts did not filter the scrolled list")
    }

    @MainActor
    private func openHistory(in app: XCUIApplication) {
        let bell = app.buttons["home.header.bell"]
        XCTAssertTrue(bell.waitForExistence(timeout: 5), "No bell")
        bell.tap()
        XCTAssertTrue(app.buttons["History"].waitForExistence(timeout: 5), "Activity did not open")
        app.buttons["History"].tap()
    }

    @MainActor
    private func scroll(_ app: XCUIApplication, until element: XCUIElement) {
        for _ in 0..<40 where !element.exists {
            app.swipeUp()
        }
    }

    @MainActor
    private func row(_ number: Int, in app: XCUIApplication) -> XCUIElement {
        let id = String(format: "00000000-0000-4000-8000-%012x", number)
        return app.descendants(matching: .any)["activity.row[\(id)]"]
    }
}
