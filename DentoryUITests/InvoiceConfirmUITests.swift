import XCTest

/// Confirm & receive (f23, MS-131) on the demo clinic's Patterson invoice: with every line resolved, the delivery is
/// received and Inventory opens with "Delivery received · Inventory increased for 3 products." over Septocaine's 250
/// more cartridges; Receive delivery no longer lists the invoice; the toast's Undo takes the delivery back out and
/// puts the invoice back in review; and Activity's History opens the received invoice read-only.
final class InvoiceConfirmUITests: XCTestCase {
    private let invoice = "receive.continue[00000000-0000-4000-8000-000000000401]"
    private let septocaineID = "00000000-0000-4000-8000-0000000000d1"
    /// The demo History's receipt from Patterson's INV-10092.
    private let receiptRow = "activity.row[00000000-0000-4000-8000-0000000000f3]"

    override func setUp() {
        continueAfterFailure = false
    }

    /// Review invoice for the Patterson invoice, from Home's Receive delivery row.
    @MainActor
    private func openInvoice() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let row = app.descendants(matching: .any)["home.receive"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No Receive delivery row on Home")
        row.tap()
        let invoiceRow = app.buttons[invoice]
        XCTAssertTrue(invoiceRow.waitForExistence(timeout: 5), "No invoice to continue reviewing")
        invoiceRow.tap()
        XCTAssertTrue(app.staticTexts["invoice.line[1].raw"].waitForExistence(timeout: 5), "The lines did not show")
        return app
    }

    /// Waits for `element`'s label to read `text`.
    @MainActor
    private func expect(_ element: XCUIElement, toRead text: String, _ message: String) {
        let reads = NSPredicate(format: "label CONTAINS %@", text)
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: reads, object: element)], timeout: 5),
            .completed, "\(message): \"\(element.label)\""
        )
    }

    /// Yes, match on the endo kit, Ignore on the surcharge, and Add new for Tempbond NE through New product.
    @MainActor
    private func resolveEveryLine(in app: XCUIApplication) {
        app.buttons["invoice.line[2].a"].tap()
        expect(app.staticTexts["invoice.line[2].headline"], toRead: "Endo file kit #15-40", "Yes, match was not saved")
        app.buttons["invoice.line[4].a"].tap()
        expect(app.staticTexts["invoice.line[4].headline"], toRead: "Ignored", "Ignore was not saved")
        app.buttons["invoice.line[3].a"].tap()
        let create = app.buttons["newProduct.submit"]
        XCTAssertTrue(create.waitForExistence(timeout: 5), "New product did not open from the line")
        create.tap()
        expect(app.staticTexts["invoice.line[3].headline"], toRead: "new product", "The product was not created")
    }

    /// The acceptance criterion on the demo: Septocaine increases by 250 cartridges, 5 boxes of 50.
    @MainActor
    func testConfirmReceivesTheDeliveryIntoInventory() {
        let app = openInvoice()
        resolveEveryLine(in: app)
        XCTAssertEqual(app.staticTexts["invoice.summary"].label, "3 of 4 lines will increase inventory.")
        let confirm = app.buttons["invoice.confirm"]
        XCTAssertTrue(confirm.isEnabled, "Confirm & receive stays disabled")
        confirm.tap()

        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Confirm & receive")
        XCTAssertTrue(toast.staticTexts["Delivery received"].exists)
        XCTAssertTrue(toast.staticTexts["Inventory increased for 3 products."].exists, "The toast detail is off")
        XCTAssertTrue(app.staticTexts["inv.header.title"].waitForExistence(timeout: 5), "Inventory did not open")
        let septocaine = app.descendants(matching: .any)["inv.row[\(septocaineID)]"]
        expect(septocaine, toRead: "304 cartridges", "Inventory does not show the 250 cartridges received")
    }

    /// The acceptance criterion: Undo restores every quantity, and the invoice waits for review again.
    @MainActor
    func testUndoTakesTheDeliveryBackOutAndTheInvoiceWaitsAgain() {
        let app = openInvoice()
        resolveEveryLine(in: app)
        app.buttons["invoice.confirm"].tap()
        // The toast shows for 3.2 seconds: Undo first, then the checks.
        let undo = app.descendants(matching: .any)["toast"].buttons["toast.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "The toast has no Undo")
        undo.tap()
        XCTAssertTrue(app.staticTexts["inv.header.title"].waitForExistence(timeout: 5), "Inventory did not open")
        // The demo's Undo bypasses the write queue that reloads Inventory on a device: choosing the tab reloads it.
        app.buttons["tab.home"].tap()
        app.buttons["tab.inventory"].tap()
        let septocaine = app.descendants(matching: .any)["inv.row[\(septocaineID)]"]
        expect(septocaine, toRead: "54 cartridges", "Undo did not take the delivery back out")

        app.buttons["tab.home"].tap()
        app.descendants(matching: .any)["home.receive"].tap()
        XCTAssertTrue(app.buttons[invoice].waitForExistence(timeout: 5), "The invoice does not wait for review again")
    }

    /// A received invoice is no longer waiting for review.
    @MainActor
    func testAReceivedInvoiceLeavesReceiveDelivery() {
        let app = openInvoice()
        resolveEveryLine(in: app)
        app.buttons["invoice.confirm"].tap()
        XCTAssertTrue(app.staticTexts["inv.header.title"].waitForExistence(timeout: 5), "Inventory did not open")

        app.buttons["tab.home"].tap()
        let row = app.descendants(matching: .any)["home.receive"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No Receive delivery row on Home")
        row.tap()
        XCTAssertTrue(app.buttons["receive.photo"].waitForExistence(timeout: 5), "Receive delivery did not open")
        XCTAssertTrue(app.buttons[invoice].waitForNonExistence(timeout: 5), "The received invoice is still listed")
    }

    /// The ticket: opening a confirmed invoice later, from Activity, shows it read-only.
    @MainActor
    func testAReceivedInvoiceOpensReadOnlyFromActivity() {
        let app = openInvoice()
        resolveEveryLine(in: app)
        app.buttons["invoice.confirm"].tap()
        XCTAssertTrue(app.staticTexts["inv.header.title"].waitForExistence(timeout: 5), "Inventory did not open")

        app.buttons["tab.home"].tap()
        let bell = app.buttons["home.header.bell"]
        XCTAssertTrue(bell.waitForExistence(timeout: 5), "No bell")
        bell.tap()
        XCTAssertTrue(app.buttons["History"].waitForExistence(timeout: 5), "Activity did not open")
        app.buttons["History"].tap()
        let receipt = app.buttons[receiptRow]
        for _ in 0..<3 where !(receipt.exists && receipt.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(receipt.waitForExistence(timeout: 5), "The receipt does not open its invoice")
        receipt.tap()

        let notice = app.staticTexts["invoice.received"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "The invoice did not open as received")
        XCTAssertTrue(notice.label.hasPrefix("Received\u{00A0}· Oct 2\u{00A0}· "), "The notice reads \(notice.label)")
        XCTAssertTrue(notice.label.hasSuffix("\u{00A0}· Sarah"), "The notice reads \(notice.label)")
        XCTAssertEqual(app.staticTexts["invoice.line[1].batch"].label, "No expiry")
        XCTAssertFalse(app.textFields["invoice.line[1].lot"].exists, "A received line takes a lot")
        XCTAssertFalse(app.buttons["invoice.line[4].undo"].exists, "A received line reopens")
        XCTAssertFalse(app.buttons["invoice.confirm"].exists, "A received invoice is confirmed again")
        XCTAssertFalse(app.buttons["invoice.menu"].exists, "A received invoice can be discarded")
    }
}
