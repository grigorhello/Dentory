import XCTest

/// Receive delivery (f22, MS-126): Home's row opens it for an admin, with the three options, the invoice to continue
/// and the lines waiting for delivery; the invoice and Receive manually lead on; Staff never reach it, not even from a
/// delivery's notification link.
final class ReceiveUITests: XCTestCase {
    private let invoice = "receive.continue[00000000-0000-4000-8000-000000000401]"
    private let needles = "receive.waiting[00000000-0000-4000-8000-000000000505]"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openReceive() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let row = app.descendants(matching: .any)["home.receive"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No Receive delivery row on Home")
        row.tap()
        XCTAssertTrue(app.staticTexts["receive.title"].waitForExistence(timeout: 5), "Receive delivery did not open")
        return app
    }

    @MainActor
    func testAdminSeesTheOptionsTheInvoiceToContinueAndWhatIsWaiting() {
        let app = openReceive()
        for (id, label) in [
            ("receive.photo", "Take a photo"), ("receive.upload", "Upload PDF or image"),
            ("receive.manual", "Receive manually")
        ] {
            let option = app.buttons[id]
            XCTAssertTrue(option.waitForExistence(timeout: 3), "Missing \(id)")
            XCTAssertTrue(option.label.contains(label), "\(id) reads \(option.label)")
        }
        XCTAssertEqual(
            app.staticTexts["receive.reassurance"].label, "Nothing affects inventory until you confirm."
        )

        let row = app.buttons[invoice]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No invoice to continue")
        XCTAssertTrue(row.label.contains("Continue reviewing"), "The invoice row reads \(row.label)")
        XCTAssertTrue(row.label.contains("Patterson · 8:55\u{202F}AM"), "The invoice row reads \(row.label)")

        XCTAssertTrue(app.staticTexts["Waiting for delivery"].exists || app.staticTexts["WAITING FOR DELIVERY"].exists)
        let waiting = app.descendants(matching: .any)[needles]
        XCTAssertTrue(waiting.exists, "No Needle 27g short waiting")
        XCTAssertEqual(waiting.label, "Needle 27g short")
        XCTAssertEqual(waiting.value as? String, "Patterson · ordered Oct 1, 60 needles ordered")
    }

    @MainActor
    func testTheInvoiceAndReceiveManuallyLeadOn() {
        let app = openReceive()
        let row = app.buttons[invoice]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No invoice to continue")
        row.tap()
        XCTAssertTrue(app.staticTexts["invoice.title"].waitForExistence(timeout: 5), "Review invoice did not open")
        XCTAssertEqual(app.staticTexts["invoice.title"].label, "Review invoice")
        app.buttons["invoice.back"].tap()

        XCTAssertTrue(app.buttons["receive.manual"].waitForExistence(timeout: 5), "Back did not return")
        app.buttons["receive.manual"].tap()
        XCTAssertTrue(app.staticTexts["manual.title"].waitForExistence(timeout: 5), "Receive manually did not open")
        app.buttons["manual.back"].tap()
        XCTAssertTrue(app.staticTexts["receive.title"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testStaffNeverReachReceiveDelivery() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["home.tile.toBuy"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["home.receive"].exists, "Staff see Receive delivery on Home")

        app.open(try XCTUnwrap(URL(string: "dentory://delivery")))
        XCTAssertTrue(app.descendants(matching: .any)["home.tile.toBuy"].waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.staticTexts["receive.title"].waitForExistence(timeout: 2), "A delivery's link opened it for Staff"
        )
    }
}
