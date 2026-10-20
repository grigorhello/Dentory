import XCTest

/// Inventory value (f10) from Home's tile: the figures as drawn, a product row to Product detail and a category row
/// to Inventory filtered by it, for Admin and Staff.
final class InventoryValueUITests: XCTestCase {
    private let anesthetic = "value.row[00000000-0000-4000-8000-0000000000c1]"
    private let septocaine = "00000000-0000-4000-8000-0000000000d1"
    private let compositeA2 = "00000000-0000-4000-8000-0000000000d3"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTheFiguresLeadToTheProductsAndTheirCategory() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openInventoryValue(in: app)

        let amount = app.staticTexts["value.total.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "The total is missing")
        XCTAssertEqual(amount.label, "Inventory value $12,420")
        let stats = [
            "atRisk": "Expiring within 90 days, $186",
            "used": "Used in the last 30 days, $2,140",
            "received": "Received in the last 30 days, $1,890"
        ]
        for (id, label) in stats {
            let stat = app.descendants(matching: .any)["value.stat.\(id)"]
            XCTAssertTrue(stat.exists, "Missing the \(id) figure")
            XCTAssertEqual(stat.label, label)
        }
        let category = app.buttons[anesthetic]
        XCTAssertTrue(category.exists, "Anesthetic is missing")
        XCTAssertTrue(category.label.contains("Anesthetic, $4,860, 39%"), "Anesthetic reads \(category.label)")

        // The most valuable product opens its Product detail, and Back returns here.
        let product = app.buttons["value.product[\(septocaine)]"]
        XCTAssertTrue(product.exists, "Septocaine is missing from the highest value products")
        XCTAssertTrue(product.label.contains("54 × $1.80"), "Septocaine reads \(product.label)")
        product.tap()
        XCTAssertTrue(app.staticTexts["product.title"].waitForExistence(timeout: 5), "Product detail did not open")
        app.buttons["product.back"].tap()
        XCTAssertTrue(app.staticTexts["value.title"].waitForExistence(timeout: 5), "Back did not return")

        // A category opens Inventory narrowed to it, its chip in front of the status chips.
        app.buttons[anesthetic].tap()
        XCTAssertTrue(app.buttons["inv.filter.category"].waitForExistence(timeout: 5), "No Anesthetic chip")
        XCTAssertTrue(app.buttons["inv.row[\(septocaine)]"].exists, "Septocaine is Anesthetic")
        XCTAssertTrue(
            app.buttons["inv.row[\(compositeA2)]"].waitForNonExistence(timeout: 3), "Composite A2 is Restorative"
        )
    }

    @MainActor
    func testStaffSeeTheSameScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff"]
        app.launch()
        openInventoryValue(in: app)

        XCTAssertTrue(app.staticTexts["value.total.amount"].waitForExistence(timeout: 5), "The total is missing")
        XCTAssertTrue(app.buttons[anesthetic].exists, "Staff cannot open a category")
        XCTAssertTrue(app.buttons["value.product[\(septocaine)]"].exists, "Staff cannot open a product")
    }

    @MainActor
    private func openInventoryValue(in app: XCUIApplication) {
        let tile = app.descendants(matching: .any)["home.tile.inventoryValue"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5), "Home has no Inventory value tile")
        tile.tap()
        XCTAssertTrue(app.staticTexts["value.title"].waitForExistence(timeout: 5), "Inventory value did not open")
    }
}
