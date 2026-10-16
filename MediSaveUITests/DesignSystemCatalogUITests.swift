import XCTest

final class DesignSystemCatalogUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLongPressOnHomeOpensTheCatalog() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let home = app.staticTexts["tab.home.placeholder"]
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        home.press(forDuration: 1)

        let catalog = app.descendants(matching: .any)["catalog.root"]
        XCTAssertTrue(catalog.waitForExistence(timeout: 5), "Catalog did not open")
        XCTAssertTrue(app.buttons["Start procedure · 6 items"].waitForExistence(timeout: 5))
    }
}
