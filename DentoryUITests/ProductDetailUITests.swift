import XCTest

final class ProductDetailUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAdminSeesTheFiguresAndAddsToBuyWithUndo() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-tab", "inventory"]
        app.launch()

        let row = app.descendants(matching: .any)["inv.row[00000000-0000-4000-8000-0000000000d1]"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The Septocaine row is missing")
        row.tap()

        XCTAssertTrue(app.staticTexts["product.title"].waitForExistence(timeout: 5), "Product detail did not open")
        XCTAssertEqual(app.staticTexts["product.context"].label, "Anesthetic · 1 box = 50 cartridges")
        XCTAssertTrue(app.staticTexts["System estimate · 38 cartridges used in 30 days"].exists)
        XCTAssertTrue(app.staticTexts["Counted Oct 1"].exists)
        XCTAssertTrue(app.staticTexts["Dec 2026"].firstMatch.exists, "No batch row")
        XCTAssertTrue(app.descendants(matching: .any)["product.expiryTotal"].exists)
        XCTAssertTrue(app.buttons["product.edit"].exists, "Admin has no Edit")
        XCTAssertTrue(app.buttons["product.adjust"].exists)

        let addToBuy = app.buttons["product.addToBuy"]
        XCTAssertEqual(addToBuy.label, "Add to buy")
        addToBuy.tap()
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Add to buy")
        XCTAssertTrue(toast.staticTexts["Added to To buy"].exists, "No toast title")
        XCTAssertTrue(toast.staticTexts["Septocaine 4% 1:100,000 · 6 cartridges"].exists, "Toast detail is off")
        XCTAssertTrue(app.buttons["On To buy"].waitForExistence(timeout: 3), "The button did not switch")
        app.buttons["toast.undo"].tap()
        XCTAssertTrue(app.buttons["Add to buy"].waitForExistence(timeout: 3), "Undo did not take it off the list")

        app.swipeUp()
        let delete = app.descendants(matching: .any)["product.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3), "Admin has no Delete product")
        app.swipeDown()
        app.buttons["product.back"].tap()
        XCTAssertTrue(app.staticTexts["inv.header.title"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testStaffSeesAddToBuyButNoEditOrDelete() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff", "-tab", "inventory"]
        app.launch()

        let row = app.descendants(matching: .any)["inv.row[00000000-0000-4000-8000-0000000000d1]"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.staticTexts["product.title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["product.addToBuy"].label, "Add to buy", "Both roles read Add to buy (G2)")
        XCTAssertFalse(app.buttons["product.edit"].exists, "Staff sees Edit")
        app.swipeUp()
        XCTAssertFalse(app.descendants(matching: .any)["product.delete"].exists, "Staff sees Delete product")
    }
}
