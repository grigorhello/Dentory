import XCTest

/// Staff login cannot see admin controls (MS-136, PRD §2): Michael, the demo clinic's Staff member, signs in on the
/// local stack and finds no screen with what only admins do (Receive delivery, Mark disposed, New product, Edit
/// product, template editing, Mark as ordered, Clinic settings, Billing, Export CSV, Invite); what Staff do is still
/// there.
final class StaffE2ETests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testStaffSeeNoAdminControls() {
        let app = E2E.signedIn(E2E.staff)
        let expiringTile = app.descendants(matching: .any)["home.tile.expiring"]
        expiringTile.appears("Home did not load")
        XCTAssertFalse(app.descendants(matching: .any)["home.receive"].exists, "Staff see Receive delivery")

        expiringTile.tap()
        let card = E2E.element("expiring.card[", labelled: "Septocaine", in: app)
        card.appears("Staff see no expiring batch")
        let cardID = card.identifier
        XCTAssertTrue(app.buttons["\(cardID).view"].exists, "Staff see no View product")
        XCTAssertFalse(app.buttons["\(cardID).dispose"].exists, "Staff see Mark disposed")
        app.buttons["expiring.back"].tap()

        app.buttons["tab.inventory"].tap()
        app.buttons["inv.countStock"].appears("Staff cannot count stock")
        XCTAssertFalse(app.descendants(matching: .any)["inv.newProduct"].exists, "Staff see New product")
        E2E.inventoryRow(E2E.product(1), searching: "Septocaine", in: app).tap()
        app.buttons["product.addToBuy"].appears("Staff cannot add to buy")
        XCTAssertFalse(app.buttons["product.edit"].exists, "Staff see Edit")
        app.swipeUp()
        XCTAssertFalse(app.descendants(matching: .any)["product.delete"].exists, "Staff see Delete product")
        app.buttons["product.back"].tap()

        app.buttons["tab.procedures"].tap()
        let rootCanal = "proc.template[\(E2E.template(1))]"
        app.descendants(matching: .any)[rootCanal].appears("No templates")
        XCTAssertFalse(app.buttons["proc.addTemplate"].exists, "Staff see + Procedure")
        XCTAssertFalse(app.buttons["\(rootCanal).edit"].exists, "Staff see a template's pencil")

        app.buttons["tab.toBuy"].tap()
        app.buttons["order.add"].appears("Staff cannot add to To buy")
        XCTAssertFalse(app.buttons["order.markOrdered"].exists, "Staff see Mark as ordered")
        XCTAssertFalse(app.descendants(matching: .any)["order.selectionBar"].exists, "Staff see the selection bar")
        let checkboxes = NSPredicate(format: "identifier ENDSWITH '.select'")
        XCTAssertEqual(app.descendants(matching: .any).matching(checkboxes).count, 0, "Staff see checkboxes")

        app.buttons["tab.home"].tap()
        app.buttons["home.header.account"].tap()
        let team = app.buttons["more.team"]
        team.appears("Account did not open")
        for id in ["more.settings", "more.billing", "more.export"] {
            XCTAssertFalse(app.buttons[id].exists, "Staff see \(id)")
        }
        team.tap()
        // Michael's own row, under his user id in the seed; for Staff it opens no menu, so it is no button.
        let michael = app.descendants(matching: .any)["team.member[d0000000-0000-4000-8000-000000000103]"]
        michael.appears("Team did not load")
        XCTAssertFalse(app.buttons["team.invite"].exists, "Staff see Invite")
    }
}
