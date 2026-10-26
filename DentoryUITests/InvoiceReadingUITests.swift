import XCTest

/// Review invoice up to its review (f23, MS-129), on the demo clinic: an invoice being read shows the reading state,
/// whose Receive manually instead sets it aside and opens Receive manually; a reading that failed offers a clearer
/// photo or receiving by hand, either of which sets it aside; and the invoice read shows its header and how many lines
/// were read.
final class InvoiceReadingUITests: XCTestCase {
    private let beingRead = "receive.continue[00000000-0000-4000-8000-000000000402]"
    private let read = "receive.continue[00000000-0000-4000-8000-000000000401]"

    override func setUp() {
        continueAfterFailure = false
    }

    /// Receive delivery from Home's row, with `-demoInvoice` adding an invoice being read when given.
    @MainActor
    private func openReceive(demoInvoice: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + (demoInvoice.map { ["-demoInvoice", $0] } ?? [])
        app.launch()
        let row = app.descendants(matching: .any)["home.receive"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No Receive delivery row on Home")
        row.tap()
        XCTAssertTrue(app.staticTexts["receive.title"].waitForExistence(timeout: 5), "Receive delivery did not open")
        return app
    }

    @MainActor
    private func open(_ invoice: String, in app: XCUIApplication) {
        let row = app.buttons[invoice]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No \(invoice) to continue")
        row.tap()
        XCTAssertTrue(app.staticTexts["invoice.title"].waitForExistence(timeout: 5), "Review invoice did not open")
    }

    @MainActor
    func testAnInvoiceBeingReadShowsTheReadingStateAndCanBeReceivedByHandInstead() {
        let app = openReceive(demoInvoice: "reading")
        let row = app.buttons[beingRead]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No invoice being read to continue")
        XCTAssertTrue(row.label.contains("Invoice · "), "An invoice being read has no supplier yet: \(row.label)")
        open(beingRead, in: app)

        XCTAssertTrue(app.staticTexts["invoice.reading.title"].waitForExistence(timeout: 5), "No reading state")
        XCTAssertEqual(app.staticTexts["invoice.reading.title"].label, "Reading invoice")
        XCTAssertEqual(app.staticTexts["invoice.reading.caption"].label, "Usually under 20 seconds.")
        XCTAssertFalse(app.staticTexts["invoice.header"].exists, "No header before the invoice is read")
        let instead = app.buttons["invoice.reading"]
        XCTAssertEqual(instead.label, "Receive manually instead")

        instead.tap()
        XCTAssertTrue(app.staticTexts["manual.title"].waitForExistence(timeout: 5), "Receive manually did not open")
        app.buttons["manual.back"].tap()
        let closed = app.staticTexts["This invoice is no longer waiting for review."]
        XCTAssertTrue(closed.waitForExistence(timeout: 5), "The invoice was not set aside")
    }

    @MainActor
    func testAFailedReadingOffersAClearerPhotoWhichReturnsToTheOptions() {
        let app = openReceive(demoInvoice: "failed")
        open(beingRead, in: app)
        let notice = app.staticTexts["invoice.failed.notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "No failure notice")
        XCTAssertEqual(notice.label, "We couldn't read this invoice. Try a clearer photo or receive manually.")

        let retry = app.buttons["invoice.failed.retry"]
        XCTAssertEqual(retry.label, "Try again")
        retry.tap()
        XCTAssertTrue(
            app.buttons["receive.photo"].waitForExistence(timeout: 5), "Try again did not return to the options"
        )
        XCTAssertTrue(app.buttons[beingRead].waitForNonExistence(timeout: 5), "The failed invoice is still listed")
        XCTAssertTrue(app.buttons[read].exists, "The invoice ready to review is still listed")
    }

    @MainActor
    func testAFailedReadingReceivedByHandIsSetAside() {
        let app = openReceive(demoInvoice: "failed")
        open(beingRead, in: app)
        let manual = app.buttons["invoice.failed.manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No failure to receive by hand")
        XCTAssertEqual(manual.label, "Receive manually")
        manual.tap()
        XCTAssertTrue(app.staticTexts["manual.title"].waitForExistence(timeout: 5), "Receive manually did not open")
        app.buttons["manual.back"].tap()
        let closed = app.staticTexts["This invoice is no longer waiting for review."]
        XCTAssertTrue(closed.waitForExistence(timeout: 5), "The failed invoice was not set aside")

        app.buttons["invoice.back"].tap()
        XCTAssertTrue(app.buttons["receive.photo"].waitForExistence(timeout: 5), "Back did not return to the options")
        XCTAssertTrue(app.buttons[beingRead].waitForNonExistence(timeout: 5), "The failed invoice is still listed")
    }

    @MainActor
    func testTheInvoiceReadShowsItsHeaderAndHowManyLinesWereRead() {
        let app = openReceive()
        open(read, in: app)
        let header = app.staticTexts["invoice.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), "No header once read")
        XCTAssertEqual(header.label, "Patterson · INV-10092 · $449.00")
        XCTAssertEqual(app.staticTexts["invoice.banner"].label, "AI read 4 lines. Check each one, then confirm.")
        XCTAssertFalse(app.buttons["invoice.reading"].exists, "No reading state once read")
    }
}
