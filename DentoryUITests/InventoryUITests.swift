import XCTest

final class InventoryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAdminBrowsesSearchesAndFilters() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.buttons["Inventory"].tap()
        XCTAssertTrue(app.staticTexts["inv.header.title"].waitForExistence(timeout: 5), "Inventory did not open")
        XCTAssertTrue(app.staticTexts["Septocaine 4% 1:100,000"].waitForExistence(timeout: 5), "No rows")
        XCTAssertTrue(app.staticTexts["54 cartridges · Anesthetic"].exists)
        XCTAssertTrue(app.staticTexts["1 unopened · 1 open · Restorative"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["inv.newProduct"].exists, "Admin has no + button")
        XCTAssertTrue(app.descendants(matching: .any)["inv.countStock"].exists, "No Count stock button")

        app.buttons["Low"].tap()
        XCTAssertTrue(app.staticTexts["Rubber dam latex-free"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Endo file kit #15-40"].exists)
        XCTAssertFalse(app.staticTexts["Septocaine 4% 1:100,000"].exists, "Low still shows a healthy product")

        app.textFields["inv.search"].firstMatch.tap()
        app.typeText("rubber")
        XCTAssertTrue(app.staticTexts["Rubber dam latex-free"].waitForExistence(timeout: 3))
        // Inventory's own row: the To buy tab, kept alive behind it, lists Endo file kit too.
        let endoRow = app.descendants(matching: .any)["inv.row[00000000-0000-4000-8000-0000000000d2]"]
        XCTAssertTrue(endoRow.waitForNonExistence(timeout: 3), "Search did not narrow the Low chip")

        app.typeText(" dam x")
        XCTAssertTrue(app.staticTexts["No products match."].waitForExistence(timeout: 3), "No empty state")
    }

    @MainActor
    func testARowOpensProductDetail() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.buttons["Inventory"].tap()
        let row = app.descendants(matching: .any)["inv.row[00000000-0000-4000-8000-0000000000d1]"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The Septocaine row is missing")
        row.tap()
        XCTAssertTrue(app.staticTexts["product.title"].waitForExistence(timeout: 5), "Product detail did not open")
        XCTAssertEqual(app.staticTexts["product.title"].label, "Septocaine 4% 1:100,000")
        XCTAssertFalse(app.buttons["Inventory"].isHittable, "Tab bar is visible on a pushed screen")
        app.buttons["product.back"].tap()
        XCTAssertTrue(app.staticTexts["inv.header.title"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeTilePreselectsTheMissingExpiryChip() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let tile = app.descendants(matching: .any)["home.tile.missingExpiry"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        XCTAssertTrue(app.staticTexts["inv.header.title"].waitForExistence(timeout: 5), "Inventory did not open")
        XCTAssertTrue(app.staticTexts["Gutta percha F2"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Septocaine 4% 1:100,000"].exists, "The chip was not applied")
        XCTAssertTrue(app.buttons["Missing expiry"].isSelected, "The Missing expiry chip is not selected")
    }

    /// The title row, the search field and the chips stay pinned while the list scrolls under them (f16-2), and so
    /// do they while counting (f18-2), so Count stock, the search and the filters are always in reach.
    @MainActor
    func testTheTitleSearchAndChipsStayPinnedWhileTheListScrolls() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-tab", "inventory"]
        app.launch()

        let title = app.staticTexts["inv.header.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Inventory did not open")
        let firstRow = app.descendants(matching: .any)["inv.row[00000000-0000-4000-8000-0000000000d7]"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "The Rubber dam row is missing")
        let pinned = PinnedElements([
            ("The title", title), ("The search field", app.textFields["inv.search"].firstMatch),
            ("The Low chip", app.buttons["Low"])
        ])
        app.swipeUp()
        app.swipeUp()
        XCTAssertFalse(firstRow.exists && firstRow.isHittable, "The list did not scroll")
        pinned.assertInReach()
        XCTAssertTrue(app.descendants(matching: .any)["inv.countStock"].isHittable, "Count stock scrolled away")
        // A chip still takes a tap 2 pt above the bottom of its 44 pt target, over the strip the rows are cut under.
        let low = app.buttons["Low"]
        low.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1 - 2 / low.frame.height)).tap()
        XCTAssertTrue(low.isSelected, "The bottom of the Low chip did not take the tap")
        app.buttons["All"].tap()

        app.buttons["inv.countStock"].tap()
        let cancel = app.buttons["inv.count.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3), "Count mode did not open")
        app.swipeUp()
        app.swipeUp()
        let firstCount = app.buttons["inv.count.row[00000000-0000-4000-8000-0000000000d7].inc"]
        XCTAssertFalse(firstCount.exists && firstCount.isHittable, "The count did not scroll")
        pinned.assertInReach()
        XCTAssertTrue(cancel.isHittable, "Cancel scrolled away")
    }

    /// The last row scrolls clear of the tab bar; Staff have no room left under it for the round +.
    @MainActor
    func testTheLastRowScrollsClearOfTheTabBar() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff", "-tab", "inventory"]
        app.launch()

        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'inv.row['"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "No rows")
        for _ in 0..<5 {
            app.swipeUp()
        }
        let lastRow = rows.element(boundBy: rows.count - 1)
        let tabBar = app.descendants(matching: .any)["tabBar"]
        XCTAssertLessThanOrEqual(lastRow.frame.maxY, tabBar.frame.minY, "The last row ends under the tab bar")
    }

    @MainActor
    func testAToastSitsJustAboveTheTabBar() {
        // To buy's Mark as ordered bar stays alive behind the other tabs; it must not lift their toasts.
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-tab", "inventory"]
        app.launch()

        // Applying a count toasts once Review's bar has gone (MS-121).
        let countStock = app.buttons["inv.countStock"]
        XCTAssertTrue(countStock.waitForExistence(timeout: 5), "No Count stock")
        countStock.tap()
        XCTAssertTrue(app.buttons["inv.count.cancel"].waitForExistence(timeout: 3), "Count mode did not open")
        app.buttons["Low"].tap()
        let inc = app.buttons["inv.count.row[00000000-0000-4000-8000-0000000000d2].inc"]
        XCTAssertTrue(inc.waitForExistence(timeout: 3), "No Endo file kit row")
        inc.tap()
        app.buttons["inv.count.review"].tap()
        let apply = app.buttons["reviewCount.apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 3), "Review corrections did not open")
        apply.tap()
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast")
        let gap = app.descendants(matching: .any)["tabBar"].frame.minY - toast.frame.maxY
        XCTAssertGreaterThanOrEqual(gap, 0, "The toast covers the tab bar")
        XCTAssertLessThan(gap, 24, "The toast floats \(gap) pt above the tab bar")
    }

    @MainActor
    func testStaffHasNoNewProductButton() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff"]
        app.launch()

        app.buttons["Inventory"].tap()
        XCTAssertTrue(app.staticTexts["Septocaine 4% 1:100,000"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["inv.newProduct"].exists, "Staff sees the + button")
        XCTAssertTrue(app.descendants(matching: .any)["inv.countStock"].exists, "Staff can count stock too")
    }
}
