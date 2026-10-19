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

    /// MS-118: Adjust then Undo restores the original quantity and both rows appear in History.
    @MainActor
    func testAdjustThenUndoRestoresTheQuantityAndWritesBothRows() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-tab", "inventory"]
        app.launch()

        let row = app.descendants(matching: .any)["inv.row[00000000-0000-4000-8000-0000000000d1]"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The Septocaine row is missing")
        row.tap()
        XCTAssertTrue(app.staticTexts["product.title"].waitForExistence(timeout: 5), "Product detail did not open")
        app.buttons["product.adjust"].tap()

        XCTAssertTrue(app.staticTexts["adjust.title"].waitForExistence(timeout: 5), "The Adjust sheet did not open")
        XCTAssertTrue(app.staticTexts["System estimate 54 cartridges. A reason is recorded in history."].exists)
        let save = app.buttons["adjust.save"]
        XCTAssertFalse(save.isEnabled, "Save is enabled before anything changed")

        // The field opens on the estimate; delete it and type the counted quantity.
        let quantity = app.textFields["adjust.quantity"]
        quantity.tap()
        let prefilled = (quantity.value as? String)?.count ?? 0
        quantity.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prefilled))
        quantity.typeText("52")
        XCTAssertFalse(save.isEnabled, "Save is enabled without a reason")
        app.buttons["adjust.reason"].tap()
        XCTAssertTrue(app.buttons["Damaged"].waitForExistence(timeout: 3), "The reasons did not open")
        app.buttons["Damaged"].tap()
        XCTAssertTrue(save.isEnabled)
        save.tap()

        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Save adjustment")
        XCTAssertTrue(toast.staticTexts["Inventory adjusted"].exists, "No toast title")
        XCTAssertTrue(toast.staticTexts["Septocaine 4% 1:100,000 · 54 → 52"].exists, "Toast detail is off")
        XCTAssertTrue(availableColumn(app, reads: "52").waitForExistence(timeout: 3), "The quantity did not move")
        app.buttons["toast.undo"].tap()
        XCTAssertTrue(availableColumn(app, reads: "54").waitForExistence(timeout: 5), "Undo did not restore 54")

        app.swipeUp()
        XCTAssertTrue(historyRow(app, reading: "Undo · Damaged · Sarah").waitForExistence(timeout: 3), "No undo row")
        XCTAssertTrue(historyRow(app, reading: "Damaged · Sarah").exists, "No adjustment row in History")
    }

    /// The Available column of the quantity card is one combined element ("Available, 52, cartridges") that
    /// carries the card's identifier itself, so it is matched directly rather than among the card's children.
    @MainActor
    private func availableColumn(_ app: XCUIApplication, reads value: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier == %@ AND label BEGINSWITH %@", "product.quantity", "Available, \(value),"
            ))
            .firstMatch
    }

    /// A history row is one combined element ("−2, Damaged · Sarah, Oct 2").
    @MainActor
    private func historyRow(_ app: XCUIApplication, reading text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "product.history[", text))
            .firstMatch
    }

    /// MS-120: opening moves one unopened to open; Finished removes the open item; the card line follows.
    @MainActor
    func testOpenANewBottleThenFinishOneUpdatesTheBottlesCard() {
        let app = XCUIApplication()
        // The Healthy chip keeps Surface disinfectant on screen: below the fold, the lazy list has no row for it.
        app.launchArguments = ["-uiTesting", "-tab", "inventory", "-inventoryFilter", "Healthy"]
        app.launch()

        // Surface disinfectant: 1 unopened · 2 open in the demo clinic.
        let row = app.descendants(matching: .any)["inv.row[00000000-0000-4000-8000-0000000000d6]"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The Surface disinfectant row is missing")
        row.tap()
        XCTAssertTrue(app.staticTexts["product.title"].waitForExistence(timeout: 5), "Product detail did not open")
        let line = app.staticTexts["product.bottles"]
        XCTAssertTrue(line.waitForExistence(timeout: 5), "No bottles card")
        XCTAssertEqual(line.label, "1 unopened · 2 open")

        let openNew = app.buttons["product.openNewBottle"]
        XCTAssertEqual(openNew.label, "Open a new bottle")
        XCTAssertTrue(openNew.isEnabled)
        openNew.tap()
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Open a new bottle")
        XCTAssertTrue(toast.staticTexts["Bottle opened"].exists, "Toast title is off")
        XCTAssertTrue(app.staticTexts["0 unopened · 3 open"].waitForExistence(timeout: 5), "The line did not move")
        XCTAssertFalse(openNew.isEnabled, "Nothing is unopened, so the button is disabled (stock rule)")

        let finished = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'product.bottle['"))
            .firstMatch
        XCTAssertTrue(finished.exists, "No Finished button")
        finished.tap()
        XCTAssertTrue(
            app.staticTexts["0 unopened · 2 open"].waitForExistence(timeout: 5), "Finished did not remove the row"
        )
        XCTAssertTrue(toast.staticTexts["Bottle finished"].waitForExistence(timeout: 5), "No toast after Finished")
        XCTAssertTrue(toast.staticTexts["Surface disinfectant · 0 unopened · 2 open"].exists, "Toast detail is off")
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
