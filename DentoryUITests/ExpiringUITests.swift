import XCTest

/// Expiring soon (f27, f28, MS-132): Home's tile, the windows, View product and the admin's Mark disposed.
final class ExpiringUITests: XCTestCase {
    private let bonding = "expiring.card[00000000-0000-4000-8000-000000000601]"
    private let septocaine = "expiring.card[00000000-0000-4000-8000-000000000602]"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openExpiring(staff: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + (staff ? ["-staff"] : [])
        app.launch()
        let tile = app.descendants(matching: .any)["home.tile.expiring"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5), "No Expiring soon tile")
        tile.tap()
        XCTAssertTrue(app.staticTexts["expiring.summary"].waitForExistence(timeout: 5), "Expiring soon did not open")
        return app
    }

    /// The acceptance flow: f27's two batches, the narrower windows, then disposing the whole Septocaine batch.
    @MainActor
    func testAdminDisposesAWholeBatch() {
        let app = openExpiring()
        let summary = app.staticTexts["expiring.summary"]
        XCTAssertEqual(summary.label, "2 products\u{00A0}· $186 at risk within 90 days.")
        XCTAssertTrue(app.descendants(matching: .any)[bonding].exists, "No Bonding agent card")
        XCTAssertTrue(app.descendants(matching: .any)[septocaine].exists, "No Septocaine card")

        app.buttons["60 days"].tap()
        XCTAssertEqual(summary.label, "1 product\u{00A0}· $82 at risk within 60 days.")
        app.buttons["30 days"].tap()
        XCTAssertTrue(app.staticTexts["Nothing expires in this window."].waitForExistence(timeout: 3))
        app.buttons["90 days"].tap()

        app.buttons["\(septocaine).dispose"].tap()
        XCTAssertTrue(app.staticTexts["dispose.title"].waitForExistence(timeout: 3), "Mark disposed did not open")
        let caption = "Septocaine 4% 1:100,000\u{00A0}· lot B441. Removed with reason Expired."
        XCTAssertTrue(app.staticTexts[caption].exists)
        XCTAssertEqual(app.textFields["dispose.quantity"].value as? String, "34")
        app.buttons["dispose.confirm"].tap()

        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast after Mark disposed")
        XCTAssertTrue(toast.staticTexts["Disposed"].exists)
        XCTAssertTrue(toast.staticTexts["34 cartridges Septocaine 4% 1:100,000"].exists)
        XCTAssertTrue(app.buttons["toast.undo"].exists, "No Undo")
        XCTAssertFalse(app.descendants(matching: .any)[septocaine].exists, "The disposed batch is still listed")
        XCTAssertEqual(summary.label, "1 product\u{00A0}· $82 at risk within 90 days.")

        // Home's tile and value at risk follow once Home reloads.
        app.buttons["expiring.back"].tap()
        let tile = app.descendants(matching: .any)["home.tile.expiring"]
        let oneExpiring = NSPredicate(format: "label == '1 Expiring soon'")
        wait(for: [expectation(for: oneExpiring, evaluatedWith: tile)], timeout: 5)
        let atRisk = app.descendants(matching: .any)["home.tile.atRisk"]
        XCTAssertTrue(atRisk.label.contains("$82"), "At risk reads \(atRisk.label)")
    }

    /// Keep closes the sheet and changes nothing; View product opens the batch's product.
    @MainActor
    func testKeepThenViewProduct() {
        let app = openExpiring()
        app.buttons["\(bonding).dispose"].tap()
        XCTAssertTrue(app.buttons["dispose.keep"].waitForExistence(timeout: 3))
        app.buttons["dispose.keep"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[bonding].waitForExistence(timeout: 3))

        app.buttons["\(septocaine).view"].tap()
        let title = app.staticTexts["product.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "View product did not open Product detail")
        XCTAssertEqual(title.label, "Septocaine 4% 1:100,000")
    }

    @MainActor
    func testStaffSeeTheBatchesWithoutMarkDisposed() {
        let app = openExpiring(staff: true)
        XCTAssertTrue(app.buttons["\(bonding).view"].exists)
        XCTAssertFalse(app.buttons["\(bonding).dispose"].exists, "Staff see Mark disposed")
        XCTAssertFalse(app.buttons["\(septocaine).dispose"].exists, "Staff see Mark disposed")
    }
}
