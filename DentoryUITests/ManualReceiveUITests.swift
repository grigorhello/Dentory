import XCTest

/// Receive manually (f24, MS-127): from Receive delivery, Choose product and its search, the labels and the line under
/// the quantity in the unit the product is received in, and Receive landing on Inventory with the toast and the new
/// stock; New on Choose product opens New product in the same sheet, Back returns to the list, and Create and select
/// chooses the new product.
final class ManualReceiveUITests: XCTestCase {
    private let septocaineID = "00000000-0000-4000-8000-0000000000d1"
    private let endoKitID = "00000000-0000-4000-8000-0000000000d2"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openReceiveManually() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let row = app.descendants(matching: .any)["home.receive"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No Receive delivery row on Home")
        row.tap()
        let manual = app.buttons["receive.manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "Receive delivery did not open")
        manual.tap()
        XCTAssertTrue(app.staticTexts["manual.title"].waitForExistence(timeout: 5), "Receive manually did not open")
        return app
    }

    @MainActor
    private func chooseProduct(_ search: String, id: String, in app: XCUIApplication) {
        app.buttons["manual.product"].tap()
        XCTAssertTrue(app.staticTexts["pickProduct.title"].waitForExistence(timeout: 5), "No Choose product sheet")
        let field = app.textFields["pickProduct.search"].firstMatch
        field.tap()
        field.typeText(search)
        let row = app.buttons["pickProduct.row[\(id)]"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "\(search) is not on Choose product")
        row.tap()
        XCTAssertTrue(app.staticTexts["pickProduct.title"].waitForNonExistence(timeout: 5), "The sheet stayed open")
    }

    /// The acceptance criterion: 5 boxes of a 50-pack add 250 cartridges, with the lot and expiry given.
    @MainActor
    func testFiveBoxesOfAFiftyPackAddTwoHundredFiftyCartridges() {
        let app = openReceiveManually()
        let product = app.buttons["manual.product"]
        XCTAssertEqual(product.value as? String, "Choose a product")
        let receive = app.buttons["manual.receive"]
        XCTAssertEqual(receive.label, "Receive")
        XCTAssertFalse(receive.isEnabled, "Receive is enabled before a product and a quantity")
        XCTAssertEqual(app.textFields["manual.qty"].label, "Quantity")
        XCTAssertEqual(app.textFields["manual.cost"].label, "Cost per unit")

        chooseProduct("septo", id: septocaineID, in: app)
        XCTAssertEqual(product.value as? String, "Septocaine 4% 1:100,000, Anesthetic · 54 cartridges in stock")
        XCTAssertEqual(app.textFields["manual.qty"].label, "Quantity (boxes)", "The quantity is not in boxes")
        XCTAssertEqual(app.textFields["manual.cost"].label, "Cost per box", "The cost is not per box")
        let effect = app.staticTexts["manual.effect"]
        XCTAssertEqual(effect.label, "1 box = 50 cartridges")

        let quantity = app.textFields["manual.qty"]
        quantity.tap()
        quantity.typeText("5")
        XCTAssertEqual(effect.label, "5 boxes = 250 cartridges · Current 54 → after 304")
        let cost = app.textFields["manual.cost"]
        cost.tap()
        cost.typeText("49.80")
        let lot = app.textFields["manual.lot"]
        lot.tap()
        lot.typeText("L-77")

        app.buttons["manual.expiry"].tap()
        let month = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(month.waitForExistence(timeout: 3), "The month wheels did not open")
        month.adjust(toPickerWheelValue: "March")
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "2027")
        XCTAssertEqual(app.buttons["manual.expiry"].value as? String, "Mar 2027")
        XCTAssertTrue(receive.isEnabled, "Receive stays disabled with a product and a quantity")
        receive.tap()

        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Receive")
        XCTAssertTrue(toast.staticTexts["Received"].exists)
        XCTAssertTrue(toast.staticTexts["Septocaine 4% 1:100,000 +250 cartridges"].exists, "The toast detail is off")
        XCTAssertFalse(toast.buttons["toast.undo"].exists, "A manual receipt has no Undo")
        XCTAssertTrue(app.staticTexts["inv.header.title"].waitForExistence(timeout: 5), "Inventory did not open")
        let row = app.descendants(matching: .any)["inv.row[\(septocaineID)]"]
        let received = NSPredicate(format: "label CONTAINS %@", "304 cartridges")
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: received, object: row)], timeout: 5),
            .completed, "Inventory does not show the 304 cartridges"
        )
    }

    /// An optional expiry: × clears a month opened by mistake, and a product received by the unit counts in its unit.
    @MainActor
    func testAKitIsReceivedByTheKitAndTheExpiryCanBeCleared() {
        let app = openReceiveManually()
        chooseProduct("endo", id: endoKitID, in: app)
        XCTAssertEqual(app.textFields["manual.qty"].label, "Quantity (kits)", "The quantity is not in kits")
        XCTAssertFalse(app.staticTexts["manual.effect"].exists, "A line before a quantity for a product without packs")
        let quantity = app.textFields["manual.qty"]
        quantity.tap()
        quantity.typeText("4")
        XCTAssertEqual(app.staticTexts["manual.effect"].label, "Current 1 → after 5 kits")

        let expiry = app.buttons["manual.expiry"]
        XCTAssertEqual(expiry.value as? String, "Optional")
        expiry.tap()
        XCTAssertTrue(app.pickerWheels.element(boundBy: 0).waitForExistence(timeout: 3), "No month wheels")
        XCTAssertEqual(expiry.value as? String, "Oct 2026", "The wheels open on this month")
        app.buttons["manual.expiry.clear"].tap()
        XCTAssertEqual(expiry.value as? String, "Optional", "× did not clear the month")
        XCTAssertFalse(app.pickerWheels.element(boundBy: 0).exists, "The wheels stayed open")

        app.buttons["manual.receive"].tap()
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Receive")
        XCTAssertTrue(toast.staticTexts["Endo file kit #15-40 +4 kits"].exists, "The toast detail is off")
        let row = app.descendants(matching: .any)["inv.row[\(endoKitID)]"]
        let received = NSPredicate(format: "label CONTAINS %@", "5 kits")
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: received, object: row)], timeout: 5),
            .completed, "Inventory does not show the 5 kits"
        )
    }

    /// Appendix C: New opens New product with a back chevron to Choose product; Create and select chooses the product.
    @MainActor
    func testNewProductFromChooseProductIsChosenOnceCreated() {
        let app = openReceiveManually()
        app.buttons["manual.product"].tap()
        XCTAssertTrue(app.staticTexts["pickProduct.title"].waitForExistence(timeout: 5), "No Choose product sheet")
        let search = app.textFields["pickProduct.search"].firstMatch
        search.tap()
        search.typeText("Articaine")
        XCTAssertTrue(app.staticTexts["No products match."].waitForExistence(timeout: 3))
        app.buttons["pickProduct.new"].tap()

        XCTAssertTrue(app.staticTexts["newProduct.title"].waitForExistence(timeout: 5), "New did not open New product")
        XCTAssertEqual(app.textFields["newProduct.name"].value as? String, "Articaine", "The name is not the search")
        app.buttons["newProduct.back"].tap()
        XCTAssertTrue(app.staticTexts["pickProduct.title"].waitForExistence(timeout: 5), "Back did not return")

        app.buttons["pickProduct.new"].tap()
        let submit = app.buttons["newProduct.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertEqual(submit.label, "Create and select")
        app.textFields["newProduct.unit"].tap()
        app.typeText("cartridges")
        app.textFields["newProduct.packUnit"].tap()
        app.typeText("box")
        let packSize = app.textFields["newProduct.packSize"]
        XCTAssertTrue(packSize.waitForExistence(timeout: 3), "The pack question did not appear")
        packSize.tap()
        packSize.typeText("50")
        if !submit.isHittable { app.swipeUp() }
        submit.tap()

        XCTAssertTrue(app.staticTexts["newProduct.title"].waitForNonExistence(timeout: 5), "The sheet stayed open")
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Create and select")
        XCTAssertTrue(toast.staticTexts["Product created"].exists)
        let product = app.buttons["manual.product"]
        let chosen = NSPredicate(format: "value == %@", "Articaine, 0 cartridges in stock")
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: chosen, object: product)], timeout: 5),
            .completed, "The new product is not chosen"
        )
        XCTAssertEqual(app.textFields["manual.qty"].label, "Quantity (boxes)")

        let quantity = app.textFields["manual.qty"]
        quantity.tap()
        quantity.typeText("2")
        XCTAssertEqual(app.staticTexts["manual.effect"].label, "2 boxes = 100 cartridges · Current 0 → after 100")
        app.buttons["manual.receive"].tap()
        XCTAssertTrue(toast.staticTexts["Articaine +100 cartridges"].waitForExistence(timeout: 5), "No receipt toast")
        XCTAssertTrue(app.staticTexts["inv.header.title"].waitForExistence(timeout: 5), "Inventory did not open")
    }
}
