import XCTest

/// To buy → Mark as ordered → receive (MS-136): the demo clinic's Rubber dam line, alone selected, is marked ordered
/// (`to_buy_mark_ordered`), waits for delivery on Receive delivery, and Receive manually's 36 sheets (`stock_receive`)
/// put it in Inventory and move the line to Received.
final class ToBuyE2ETests: XCTestCase {
    private let rubberDam = E2E.product(7)

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testARubberDamLineIsOrderedThenReceived() {
        let app = E2E.signedIn(E2E.admin)
        app.buttons["tab.toBuy"].tap()
        // A toggle to XCUITest, not a button.
        let checkbox = app.descendants(matching: .any)["Select Rubber dam latex-free"]
        checkbox.appears("Rubber dam is not on To buy")
        // The line's own id, which the seed leaves random, names its rows under Ordered and Received too.
        let lineID = String(checkbox.identifier.dropFirst("order.row[".count).dropLast("].select".count))

        let toggle = app.buttons["order.selectionBar.toggle"]
        if toggle.label == "Clear" { toggle.tap() }
        checkbox.tap()
        let markOrdered = app.buttons["order.markOrdered"]
        E2E.expect(markOrdered, toRead: "Mark 1 as ordered", "Only Rubber dam is selected")
        markOrdered.tap()
        E2E.expectToast("Marked as ordered", "1 item", in: app)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Ordered'")).firstMatch.tap()
        let ordered = app.descendants(matching: .any)["order.ordered[\(lineID)]"]
        ordered.appears("Rubber dam is not under Ordered")

        app.buttons["tab.home"].tap()
        app.descendants(matching: .any)["home.receive"].tap()
        let waiting = app.descendants(matching: .any)["receive.waiting[\(lineID)]"]
        waiting.appears("Rubber dam is not waiting for delivery")
        XCTAssertEqual(waiting.label, "Rubber dam latex-free")

        app.buttons["receive.manual"].tap()
        app.buttons["manual.product"].tap()
        let search = app.textFields["pickProduct.search"].firstMatch
        search.appears("No Choose product sheet")
        search.tap()
        search.typeText("rubber")
        let product = app.buttons["pickProduct.row[\(rubberDam)]"]
        product.appears("Rubber dam is not on Choose product")
        product.tap()
        let quantity = app.textFields["manual.qty"]
        quantity.appears("Choose product did not close")
        quantity.tap()
        quantity.typeText("36")
        XCTAssertEqual(app.staticTexts["manual.effect"].label, "Current 0 → after 36 sheets")
        app.buttons["manual.receive"].tap()
        E2E.expectToast("Received", "Rubber dam latex-free +36 sheets", in: app)
        let row = E2E.inventoryRow(rubberDam, searching: "Rubber dam", in: app)
        E2E.expect(row, toRead: "36 sheets", "Inventory does not show the sheets received")

        app.buttons["tab.toBuy"].tap()
        let received = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Received'")).firstMatch
        received.appears("No Received segment")
        received.tap()
        app.descendants(matching: .any)["order.received[\(lineID)]"].appears("The line did not move to Received")
    }
}
