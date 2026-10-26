import XCTest

/// Expiring soon → Mark disposed (MS-136): from Home's tile, the demo clinic's Bonding agent bottle in lot BA7 is
/// disposed whole through `stock_dispose`; its card leaves the list, and Inventory keeps only the open bottle.
final class ExpiringE2ETests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTheExpiringBondingAgentBottleIsDisposed() {
        let app = E2E.signedIn(E2E.admin)
        let tile = app.descendants(matching: .any)["home.tile.expiring"]
        tile.appears("No Expiring soon tile")
        tile.tap()
        app.staticTexts["expiring.summary"].appears("Expiring soon did not open")
        // A card is named after its batch, whose id the seed leaves random.
        let card = E2E.element("expiring.card[", labelled: "Bonding agent", in: app)
        card.appears("No Bonding agent card")
        XCTAssertTrue(card.label.contains("1 bottle · lot BA7"), "The card reads \(card.label)")
        let cardID = card.identifier

        app.buttons["\(cardID).dispose"].tap()
        let caption = app.staticTexts["Bonding agent · lot BA7. Removed with reason Expired."]
        caption.appears("Mark disposed did not open for the batch")
        XCTAssertEqual(app.textFields["dispose.quantity"].value as? String, "1", "The whole batch is not the default")
        app.buttons["dispose.confirm"].tap()
        E2E.expectToast("Disposed", "1 bottle Bonding agent", in: app)
        let disposed = app.descendants(matching: .any)[cardID]
        XCTAssertTrue(disposed.waitForNonExistence(timeout: E2E.patience), "The batch disposed is still listed")

        app.buttons["expiring.back"].tap()
        app.buttons["tab.inventory"].tap()
        let bonding = E2E.inventoryRow(E2E.product(4), searching: "Bonding", in: app)
        E2E.expect(bonding, toRead: "0 unopened · 1 open", "The bottle disposed is still in stock")
    }
}
