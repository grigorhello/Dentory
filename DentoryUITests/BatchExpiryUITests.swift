import XCTest

final class BatchExpiryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Gutta percha F2 holds 7 packs with no expiry date: dating all of them clears Missing expiry.
    @MainActor
    func testAddingExpiryToAllUndatedStockClearsMissingExpiry() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-tab", "inventory"]
        app.launch()
        openProduct("00000000-0000-4000-8000-0000000000d8", in: app)
        let status = app.descendants(matching: .any)["product.status"]
        XCTAssertEqual(status.label, "Missing expiry")
        XCTAssertTrue(app.descendants(matching: .any)["product.expiryEmpty"].exists, "No empty expiry state")

        app.buttons["product.addExpiry"].tap()
        XCTAssertTrue(app.staticTexts["batch.title"].waitForExistence(timeout: 5), "No Add expiry sheet")
        XCTAssertEqual(app.staticTexts["batch.title"].label, "Add expiry")
        XCTAssertEqual(app.textFields["batch.quantity"].value as? String, "7", "How many does not start undated")
        XCTAssertTrue(app.staticTexts["7 packs come from stock with no expiry date."].exists)
        let save = app.buttons["batch.save"]
        XCTAssertFalse(save.isEnabled, "Save is enabled without a month")

        app.buttons["batch.expires"].tap()
        let month = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(month.waitForExistence(timeout: 3), "The month wheels did not open")
        month.adjust(toPickerWheelValue: "March")
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "2027")
        XCTAssertEqual(app.buttons["batch.expires"].value as? String, "Mar 2027")
        XCTAssertTrue(save.isEnabled)
        save.tap()

        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Save")
        XCTAssertTrue(toast.staticTexts["Expiry saved"].exists)
        XCTAssertTrue(toast.staticTexts["Gutta percha F2 · 7 packs · Mar 2027"].exists, "The toast detail is off")
        let healthy = NSPredicate(format: "label == %@", "Healthy")
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: healthy, object: status)], timeout: 5),
            .completed, "Missing expiry did not clear"
        )
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'product.batch[' AND label CONTAINS 'Mar 2027'"))
            .firstMatch
        XCTAssertTrue(row.exists, "No batch row for March 2027")
    }

    /// Both roles edit a batch: Staff changes the lot of Septocaine's December batch.
    @MainActor
    func testStaffEditsABatchLot() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff", "-tab", "inventory"]
        app.launch()
        openProduct("00000000-0000-4000-8000-0000000000d1", in: app)
        let batch = app.buttons["product.batch[00000000-0000-4000-8000-0000000000b1]"]
        XCTAssertTrue(batch.waitForExistence(timeout: 5), "No A112 batch row")
        batch.tap()

        XCTAssertTrue(app.staticTexts["batch.title"].waitForExistence(timeout: 5), "No Edit batch sheet")
        XCTAssertEqual(app.staticTexts["batch.title"].label, "Edit batch")
        XCTAssertEqual(app.buttons["batch.expires"].value as? String, "Dec 2026")
        let save = app.buttons["batch.save"]
        XCTAssertFalse(save.isEnabled, "Save is enabled before anything changed")
        let lot = app.textFields["batch.lot"]
        lot.tap()
        let current = (lot.value as? String)?.count ?? 0
        lot.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current) + "A113")
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(app.descendants(matching: .any)["toast"].waitForExistence(timeout: 5), "No toast after Save")
        let edited = NSPredicate(format: "label CONTAINS %@", "A113")
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: edited, object: batch)], timeout: 5),
            .completed, "The batch row does not show the new lot"
        )
    }

    @MainActor
    private func openProduct(_ id: String, in app: XCUIApplication) {
        let row = app.descendants(matching: .any)["inv.row[\(id)]"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The product row is missing")
        if !row.isHittable { app.swipeUp() }
        row.tap()
        XCTAssertTrue(app.staticTexts["product.title"].waitForExistence(timeout: 5), "Product detail did not open")
    }
}
