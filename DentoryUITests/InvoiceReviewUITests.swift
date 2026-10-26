import XCTest

/// Review invoice's lines (f23, MS-130) on the demo clinic's Patterson invoice: the four lines as the frame draws them;
/// Yes, match, Add new through New product, Ignore and Pick product through Which product is this?; the badge and Undo
/// reopening a line; the badge of the line read as Matched and of the Possible match pointing it at another product
/// (the decision on #101); every choice, lot and expiry still there after leaving and coming back; Confirm & receive
/// enabled once every line is resolved; and Discard invoice asking first, then leaving Receive delivery without the
/// invoice.
final class InvoiceReviewUITests: XCTestCase {
    private let invoice = "receive.continue[00000000-0000-4000-8000-000000000401]"
    private let glovesID = "00000000-0000-4000-8000-0000000000d5"
    private let rubberDamID = "00000000-0000-4000-8000-0000000000d7"
    private let guttaPerchaID = "00000000-0000-4000-8000-0000000000d8"

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
        reopen(in: app)
        return app
    }

    /// Continue reviewing on Receive delivery, until the lines show.
    @MainActor
    private func reopen(in app: XCUIApplication) {
        let row = app.buttons[invoice]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No invoice to continue reviewing")
        row.tap()
        XCTAssertTrue(app.staticTexts["invoice.line[1].raw"].waitForExistence(timeout: 5), "The lines did not show")
    }

    @MainActor
    private func headline(_ number: Int, in app: XCUIApplication) -> String {
        app.staticTexts["invoice.line[\(number)].headline"].label
    }

    /// Waits for a line's headline to read `text` after a choice is saved.
    @MainActor
    private func expectHeadline(_ number: Int, _ text: String, in app: XCUIApplication) {
        let element = app.staticTexts["invoice.line[\(number)].headline"]
        let reads = NSPredicate(format: "label == %@", text)
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: reads, object: element)], timeout: 5),
            .completed, "Line \(number) reads \"\(element.label)\", not \"\(text)\""
        )
    }

    /// Searches Which product is this? and taps the product, which closes the sheet.
    @MainActor
    private func pick(_ search: String, id: String, in app: XCUIApplication) {
        let field = app.textFields["match.search"].firstMatch
        field.tap()
        field.typeText(search)
        let row = app.buttons["match.row[\(id)]"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "\(search) is not on the list")
        row.tap()
        XCTAssertTrue(app.staticTexts["match.title"].waitForNonExistence(timeout: 5), "The sheet stayed open")
    }

    @MainActor
    func testTheFramesFourLinesWaitForTheirChoices() {
        let app = openInvoice()
        XCTAssertEqual(app.staticTexts["invoice.banner"].label, "AI read 4 lines. Check each one, then confirm.")
        let raws = (1...4).map { app.staticTexts["invoice.line[\($0)].raw"].label }
        XCTAssertEqual(raws, [
            "SEPTO 4% 1:100K 50/BX", "ENDO FILE KIT 15-40 21MM", "TEMPBOND NE 1PK", "HANDLING / FUEL SURCHARGE"
        ])
        XCTAssertEqual((1...4).map { headline($0, in: app) }, [
            "Septocaine 4% 1:100,000", "Is this Endo file kit #15-40?", "Not in your inventory",
            "Looks like a fee, not a product"
        ])
        let states = (1...4).map { app.descendants(matching: .any)["invoice.line[\($0)].state"].label }
        XCTAssertEqual(states, ["Matched", "Possible match", "New product", "Needs review"])
        XCTAssertEqual(app.staticTexts["invoice.line[1].amount"].label, "5 boxes\u{00A0}· $49.80")
        XCTAssertEqual(app.staticTexts["invoice.line[4].amount"].label, "1\u{00A0}· $4.80")
        let choices = (2...4).map { line in
            ["a", "b"].map { app.buttons["invoice.line[\(line)].\($0)"].label }
        }
        XCTAssertEqual(choices, [
            ["Yes, match", "No, create new"], ["Add new", "Pick existing"], ["Ignore", "Pick product"]
        ])
        XCTAssertTrue(app.buttons["invoice.line[1].expiry"].exists, "A Matched line has its Expiry")
        XCTAssertTrue(app.textFields["invoice.line[1].lot"].exists, "and its Lot")
        XCTAssertEqual(app.staticTexts["invoice.summary"].label, "Resolve every line to continue.")
        let confirm = app.buttons["invoice.confirm"]
        XCTAssertEqual(confirm.label, "Confirm & receive")
        XCTAssertFalse(confirm.isEnabled, "Confirm & receive is enabled before every line is resolved")
    }

    /// The acceptance criterion: each transition works and survives leaving and reopening the screen.
    @MainActor
    func testEachLineIsResolvedAndStaysSoAfterLeavingAndComingBack() {
        let app = openInvoice()
        app.buttons["invoice.line[2].a"].tap()
        expectHeadline(2, "Endo file kit #15-40", in: app)
        XCTAssertEqual(app.buttons["invoice.line[2].state"].label, "Matched")

        app.buttons["invoice.line[4].a"].tap()
        expectHeadline(4, "Ignored\u{00A0}· not added to inventory", in: app)
        XCTAssertEqual(app.buttons["invoice.line[4].undo"].label, "Undo")

        app.buttons["invoice.line[3].a"].tap()
        let notice = app.staticTexts["newProduct.fromInvoice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "New product did not open from the line")
        XCTAssertEqual(
            notice.label, "From invoice: TEMPBOND NE 1PK. Name and unit are suggested. Check them and add the rest."
        )
        XCTAssertEqual(app.textFields["newProduct.name"].value as? String, "Tempbond NE")
        XCTAssertEqual(app.textFields["newProduct.unit"].value as? String, "packs")
        let create = app.buttons["newProduct.submit"]
        XCTAssertEqual(create.label, "Create and use for this line")
        create.tap()
        expectHeadline(3, "Tempbond NE\u{00A0}· new product", in: app)
        XCTAssertEqual(app.buttons["invoice.line[3].state"].label, "Created")

        XCTAssertEqual(app.staticTexts["invoice.summary"].label, "3 of 4 lines will increase inventory.")
        XCTAssertTrue(app.buttons["invoice.confirm"].isEnabled, "Confirm & receive stays disabled")

        app.buttons["invoice.back"].tap()
        reopen(in: app)
        expectHeadline(2, "Endo file kit #15-40", in: app)
        expectHeadline(3, "Tempbond NE\u{00A0}· new product", in: app)
        expectHeadline(4, "Ignored\u{00A0}· not added to inventory", in: app)

        app.buttons["invoice.line[2].state"].tap()
        expectHeadline(2, "Is this Endo file kit #15-40?", in: app)
        app.buttons["invoice.line[4].undo"].tap()
        expectHeadline(4, "Looks like a fee, not a product", in: app)
        XCTAssertEqual(app.staticTexts["invoice.summary"].label, "Resolve every line to continue.")
        XCTAssertFalse(app.buttons["invoice.confirm"].isEnabled)
    }

    @MainActor
    func testPickProductMatchesAFeeFromWhichProductIsThis() {
        let app = openInvoice()
        app.buttons["invoice.line[4].b"].tap()
        let title = app.staticTexts["match.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Which product is this? did not open")
        XCTAssertEqual(app.staticTexts["match.title"].label, "Which product is this?")
        XCTAssertEqual(app.staticTexts["match.code"].label, "HANDLING / FUEL SURCHARGE")
        pick("nitrile", id: glovesID, in: app)
        expectHeadline(4, "Nitrile gloves M", in: app)
        XCTAssertEqual(app.buttons["invoice.line[4].state"].label, "Matched")
    }

    /// The decision on #101: the badge of the line read as Matched opens Which product is this?, the product picked
    /// replaces the one read, and the badge then reopens the line to it; the Possible match is pointed at another
    /// product the same way. Both stay so after leaving and coming back.
    @MainActor
    func testTheBadgePointsTheMatchedLineAndThePossibleMatchAtAnotherProduct() {
        let app = openInvoice()
        let title = app.staticTexts["match.title"]
        app.buttons["invoice.line[1].state"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Which product is this? did not open from the Matched badge")
        XCTAssertEqual(app.staticTexts["match.code"].label, "SEPTO 4% 1:100K 50/BX")
        pick("gutta", id: guttaPerchaID, in: app)
        expectHeadline(1, "Gutta percha F2", in: app)
        XCTAssertEqual(app.buttons["invoice.line[1].state"].label, "Matched")

        app.buttons["invoice.line[2].state"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Which product is this? did not open for the Possible match")
        XCTAssertEqual(app.staticTexts["match.code"].label, "ENDO FILE KIT 15-40 21MM")
        pick("rubber", id: rubberDamID, in: app)
        expectHeadline(2, "Rubber dam latex-free", in: app)
        XCTAssertEqual(app.buttons["invoice.line[2].state"].label, "Matched")

        app.buttons["invoice.back"].tap()
        reopen(in: app)
        expectHeadline(1, "Gutta percha F2", in: app)
        expectHeadline(2, "Rubber dam latex-free", in: app)

        app.buttons["invoice.line[1].state"].tap()
        expectHeadline(1, "Septocaine 4% 1:100,000", in: app)
        app.buttons["invoice.line[2].state"].tap()
        expectHeadline(2, "Is this Endo file kit #15-40?", in: app)
        XCTAssertFalse(title.exists, "A badge that reopens opened Which product is this?")
    }

    @MainActor
    func testTheLotAndExpiryOfAMatchedLineAreKept() {
        let app = openInvoice()
        let lot = app.textFields["invoice.line[1].lot"]
        XCTAssertEqual(lot.placeholderValue, "Free text")
        lot.tap()
        lot.typeText("A112\n")
        let expiry = app.buttons["invoice.line[1].expiry"]
        XCTAssertEqual(expiry.value as? String, "Month")
        expiry.tap()
        XCTAssertTrue(app.pickerWheels.element(boundBy: 0).waitForExistence(timeout: 3), "No month wheels")
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "March")
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "2028")
        XCTAssertEqual(expiry.value as? String, "Mar 2028")
        XCTAssertEqual(
            app.staticTexts["invoice.line[1].expiryHint"].label, "No expiry → listed under Missing expiry."
        )

        app.buttons["invoice.back"].tap()
        reopen(in: app)
        XCTAssertEqual(app.textFields["invoice.line[1].lot"].value as? String, "A112")
        XCTAssertEqual(app.buttons["invoice.line[1].expiry"].value as? String, "Mar 2028")
    }

    @MainActor
    func testDiscardInvoiceAsksFirstThenLeavesItOutOfReceiveDelivery() {
        let app = openInvoice()
        let menu = app.buttons["invoice.menu"]
        XCTAssertEqual(menu.label, "More")
        menu.tap()
        let discard = app.buttons["invoice.menu.discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5), "The menu did not open")
        discard.tap()
        let question = app.staticTexts["invoice.discard.title"]
        XCTAssertTrue(question.waitForExistence(timeout: 5), "Discard invoice did not ask first")
        XCTAssertEqual(question.label, "Discard this invoice?")
        XCTAssertEqual(
            app.staticTexts["invoice.discard.message"].label,
            "Nothing is added to inventory. The photo or file is deleted."
        )
        app.buttons["invoice.discard.keep"].tap()
        XCTAssertTrue(question.waitForNonExistence(timeout: 5), "Keep did not close the question")
        XCTAssertTrue(app.staticTexts["invoice.line[1].raw"].exists, "Keep left the invoice")

        menu.tap()
        app.buttons["invoice.menu.discard"].tap()
        XCTAssertTrue(app.buttons["invoice.discard.confirm"].waitForExistence(timeout: 5))
        app.buttons["invoice.discard.confirm"].tap()
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Discard invoice")
        XCTAssertTrue(toast.staticTexts["Invoice discarded"].exists)
        XCTAssertTrue(app.buttons["receive.photo"].waitForExistence(timeout: 5), "Receive delivery did not show again")
        XCTAssertTrue(app.buttons[invoice].waitForNonExistence(timeout: 5), "The invoice is still listed")
    }
}
