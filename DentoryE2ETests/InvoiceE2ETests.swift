import XCTest

/// Receive invoice (fixture) → confirm (MS-136): Northbridge's PDF picked on Upload PDF or image goes to the invoices
/// bucket, `invoice_create` makes the invoice and `extract_invoice` reads it, with the recorded answer on the local
/// stack; the matching gives f23's four lines; each is resolved; Confirm & receive puts 250 Septocaine cartridges and 4
/// endo kits into Inventory and creates Tempbond NE.
final class InvoiceE2ETests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAnUploadedInvoiceIsReadReviewedAndReceived() {
        let app = E2E.signedIn(E2E.admin, arguments: ["-receiveFile", E2E.invoiceFixture])
        app.descendants(matching: .any)["home.receive"].tap()
        let upload = app.buttons["receive.upload"]
        upload.appears("Receive delivery did not open")
        upload.tap()

        let header = app.staticTexts["invoice.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 60), "The invoice was not read")
        XCTAssertEqual(header.label, "Northbridge Dental Supply · INV-10092 · $520.03")
        XCTAssertEqual(app.staticTexts["invoice.banner"].label, "AI read 4 lines. Check each one, then confirm.")
        let states = (1...4).map { app.descendants(matching: .any)["invoice.line[\($0)].state"].label }
        XCTAssertEqual(states, ["Matched", "Possible match", "New product", "Needs review"])
        XCTAssertEqual(app.staticTexts["invoice.line[1].headline"].label, "Septocaine 4% 1:100,000")
        XCTAssertFalse(app.buttons["invoice.confirm"].isEnabled, "Confirm & receive before every line is resolved")

        app.buttons["invoice.line[2].a"].tap()
        E2E.expect(app.staticTexts["invoice.line[2].headline"], toRead: "Endo file kit #15-40", "Yes, match")
        app.buttons["invoice.line[4].a"].tap()
        E2E.expect(app.staticTexts["invoice.line[4].headline"], toRead: "Ignored", "Ignore")
        app.buttons["invoice.line[3].a"].tap()
        let create = app.buttons["newProduct.submit"]
        create.appears("New product did not open from the line")
        XCTAssertEqual(app.textFields["newProduct.name"].value as? String, "Tempbond NE")
        create.tap()
        E2E.expect(app.staticTexts["invoice.line[3].headline"], toRead: "Tempbond NE · new product", "Add new")

        XCTAssertEqual(app.staticTexts["invoice.summary"].label, "3 of 4 lines will increase inventory.")
        let confirm = app.buttons["invoice.confirm"]
        XCTAssertTrue(confirm.isEnabled, "Confirm & receive stays disabled")
        confirm.tap()

        E2E.expectToast("Delivery received", "Inventory increased for 3 products.", in: app)
        app.staticTexts["inv.header.title"].appears("Inventory did not open")
        let septocaine = E2E.inventoryRow(E2E.product(1), searching: "Septocaine", in: app)
        E2E.expect(septocaine, toRead: "304 cartridges", "Septocaine did not get its 250 cartridges")
        let endoKits = E2E.inventoryRow(E2E.product(2), searching: "Endo file kit", in: app)
        E2E.expect(endoKits, toRead: "5 kits", "The endo file kits did not arrive")
    }
}
