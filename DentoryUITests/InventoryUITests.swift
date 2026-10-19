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
        XCTAssertFalse(app.staticTexts["Endo file kit #15-40"].exists, "Search did not narrow the Low chip")

        app.typeText(" dam x")
        XCTAssertTrue(app.staticTexts["No products match."].waitForExistence(timeout: 3), "No empty state")

        app.descendants(matching: .any)["inv.search"].firstMatch.tap()
        app.buttons["All"].tap()
        app.textFields["inv.search"].firstMatch.tap()
        app.typeText(XCUIKeyboardKey.delete.rawValue)
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
