import XCTest

final class ProductFormUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAdminCreatesAProductWithALivePackSentence() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-tab", "inventory"]
        app.launch()

        let add = app.buttons["inv.newProduct"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "No + button for Admin")
        add.tap()
        XCTAssertTrue(app.staticTexts["newProduct.title"].waitForExistence(timeout: 5), "No New product sheet")
        XCTAssertEqual(app.staticTexts["newProduct.title"].label, "New product")
        let submit = app.buttons["newProduct.submit"]
        XCTAssertEqual(submit.label, "Create product")
        XCTAssertFalse(submit.isEnabled, "Create is enabled before a name and unit are entered")

        app.textFields["newProduct.name"].tap()
        app.typeText("Articaine 4%")
        app.textFields["newProduct.unit"].tap()
        app.typeText("cartridges")
        XCTAssertTrue(submit.isEnabled, "Name and unit entered, Create stays disabled")
        app.textFields["newProduct.packUnit"].tap()
        app.typeText("box")
        let packSize = app.textFields["newProduct.packSize"]
        XCTAssertTrue(packSize.waitForExistence(timeout: 3), "The pack question did not appear")
        XCTAssertTrue(app.staticTexts["Stock is counted in the smaller unit."].exists)
        packSize.tap()
        app.typeText("50")
        XCTAssertTrue(
            app.staticTexts["Receive in boxes, count and use in cartridges. 1 box adds 50 cartridges."]
                .waitForExistence(timeout: 3),
            "The conversion sentence did not update live"
        )
        app.textFields["newProduct.minimum"].tap()
        app.typeText("10")
        app.textFields["newProduct.target"].tap()
        app.typeText("40")
        XCTAssertTrue(app.staticTexts["newProduct.receivingHint"].exists, "No receiving hint on a new product")
        submit.tap()

        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Create product")
        XCTAssertTrue(toast.staticTexts["Product created"].exists)
        XCTAssertTrue(
            app.staticTexts["Articaine 4%"].waitForExistence(timeout: 5), "The new product is not in the list"
        )
    }

    @MainActor
    func testAdminEditsThenDeletesAProduct() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-tab", "inventory"]
        app.launch()

        let row = app.descendants(matching: .any)["inv.row[00000000-0000-4000-8000-0000000000d1]"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The Septocaine row is missing")
        row.tap()
        XCTAssertTrue(app.staticTexts["product.title"].waitForExistence(timeout: 5), "Product detail did not open")
        app.buttons["product.edit"].tap()
        XCTAssertTrue(app.staticTexts["newProduct.title"].waitForExistence(timeout: 5), "No Edit sheet")
        XCTAssertEqual(app.staticTexts["newProduct.title"].label, "Edit product")
        let name = app.textFields["newProduct.name"]
        XCTAssertEqual(name.value as? String, "Septocaine 4% 1:100,000")
        XCTAssertFalse(app.staticTexts["newProduct.receivingHint"].exists, "The receiving hint shows while editing")
        // A product with stock keeps how it is tracked (G1).
        app.switches["newProduct.multiUse"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["newProduct.trackingError"].waitForExistence(timeout: 3), "No inline error")
        name.tap()
        app.typeText(" Gold")
        let submit = app.buttons["newProduct.submit"]
        XCTAssertEqual(submit.label, "Save changes")
        submit.tap()
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Save changes")
        XCTAssertTrue(toast.staticTexts["Changes saved"].exists)
        XCTAssertTrue(
            app.staticTexts["Septocaine 4% 1:100,000 Gold"].waitForExistence(timeout: 5), "The title did not change"
        )

        app.swipeUp()
        let delete = app.descendants(matching: .any)["product.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3), "No Delete product")
        delete.tap()
        XCTAssertTrue(app.staticTexts["deleteProduct.title"].waitForExistence(timeout: 5), "No Delete sheet")
        XCTAssertEqual(app.staticTexts["deleteProduct.title"].label, "Delete Septocaine 4% 1:100,000 Gold?")
        XCTAssertTrue(app.staticTexts["deleteProduct.message"].label.hasPrefix("54 cartridges still in stock."))
        app.buttons["deleteProduct.keep"].tap()
        XCTAssertTrue(app.staticTexts["deleteProduct.title"].waitForNonExistence(timeout: 3), "Keep did not close")
        delete.tap()
        XCTAssertTrue(app.buttons["deleteProduct.confirm"].waitForExistence(timeout: 5))
        app.buttons["deleteProduct.confirm"].tap()
        XCTAssertTrue(app.staticTexts["inv.header.title"].waitForExistence(timeout: 5), "Did not return to Inventory")
        let deleted = app.descendants(matching: .any)["toast"].staticTexts["Product deleted"]
        XCTAssertTrue(deleted.waitForExistence(timeout: 3), "No Product deleted toast")
        XCTAssertFalse(row.exists, "The deleted product is still listed")
    }

    @MainActor
    func testStaffSeesNoNewProductSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff", "-tab", "inventory"]
        app.launch()
        XCTAssertTrue(app.staticTexts["inv.header.title"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["inv.newProduct"].exists, "Staff sees the + button")
    }
}
