import XCTest

/// Count stock → Apply count (MS-136): two of the demo clinic's products counted in Count mode, found through the
/// search, reviewed, and applied through `stock_count_apply`; Inventory then shows the counted quantities.
final class CountStockE2ETests: XCTestCase {
    private let matrixBands = E2E.product(25)
    private let paperPoints = E2E.product(22)

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTwoCorrectionsAreCountedReviewedAndApplied() {
        let app = E2E.signedIn(E2E.admin)
        app.buttons["tab.inventory"].tap()
        let countStock = app.buttons["inv.countStock"]
        XCTAssertTrue(countStock.waitForExistence(timeout: 10), "No Count stock button")
        countStock.tap()
        XCTAssertTrue(app.buttons["inv.count.cancel"].waitForExistence(timeout: 10), "Count mode did not open")

        E2E.searchInventory(for: "Matrix band", in: app)
        let fewerBands = app.buttons["inv.count.row[\(matrixBands)].dec"]
        XCTAssertTrue(fewerBands.waitForExistence(timeout: 10), "Matrix band is not counted")
        fewerBands.tap()
        fewerBands.tap()
        XCTAssertEqual(app.staticTexts["inv.count.row[\(matrixBands)].value"].label, "33")
        E2E.searchInventory(for: "Paper points", in: app)
        let morePoints = app.buttons["inv.count.row[\(paperPoints)].inc"]
        XCTAssertTrue(morePoints.waitForExistence(timeout: 10), "Paper points are not counted")
        morePoints.tap()
        XCTAssertEqual(app.staticTexts["inv.count.row[\(paperPoints)].value"].label, "6")

        let review = app.buttons["inv.count.review"]
        XCTAssertEqual(review.label, "Review · 2 corrections", "A count was lost while searching")
        review.tap()
        XCTAssertTrue(app.staticTexts["reviewCount.title"].waitForExistence(timeout: 10), "Review did not open")
        XCTAssertEqual(app.staticTexts["reviewCount.row[\(matrixBands)].change"].label, "35 → 33")
        XCTAssertEqual(app.staticTexts["reviewCount.row[\(paperPoints)].change"].label, "5 → 6")
        let apply = app.buttons["reviewCount.apply"]
        XCTAssertEqual(apply.label, "Apply count · 2 corrections")
        apply.tap()

        E2E.expectToast("Count applied", "2 products updated", in: app)
        XCTAssertTrue(countStock.waitForExistence(timeout: 10), "Still in count mode")
        let bands = E2E.inventoryRow(matrixBands, searching: "Matrix band", in: app)
        E2E.expect(bands, toRead: "33 bands", "Inventory does not show the count")
        let points = E2E.inventoryRow(paperPoints, searching: "Paper points", in: app)
        E2E.expect(points, toRead: "6 packs", "Inventory does not show the count")
    }
}
