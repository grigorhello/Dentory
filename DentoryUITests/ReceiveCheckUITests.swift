import UIKit
import XCTest

/// Check an invoice photo before it is read (MS-163): an image too dark to read, taken as if picked in Files through
/// the Debug `-receiveFile` hook, opens the check's sheet instead of Review invoice; Use anyway goes on to Review
/// invoice, and closing the sheet drops the image.
final class ReceiveCheckUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// A black page as a JPEG in the runner's temporary folder, which the app in the same simulator can read.
    @MainActor
    private func darkImagePath() throws -> String {
        let size = CGSize(width: 600, height: 800)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "receive-check-dark.jpg")
        try XCTUnwrap(image.jpegData(compressionQuality: 0.8)).write(to: url)
        return url.path
    }

    /// Receive delivery from Home's row, then Upload PDF or image, which takes the dark image.
    @MainActor
    private func uploadDarkImage() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-receiveFile", try darkImagePath()]
        app.launch()
        let row = app.descendants(matching: .any)["home.receive"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No Receive delivery row on Home")
        row.tap()
        let upload = app.buttons["receive.upload"]
        XCTAssertTrue(upload.waitForExistence(timeout: 5), "Receive delivery did not open")
        upload.tap()
        return app
    }

    @MainActor
    func testADarkImageAsksForAnotherAndUseAnywayGoesOnToReviewInvoice() throws {
        let app = try uploadDarkImage()
        let title = app.staticTexts["receive.check.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "The check's sheet did not open")
        XCTAssertEqual(title.label, "This image is too dark")
        XCTAssertEqual(app.staticTexts["receive.check.message"].label, "It is too dark, so lines could be missed.")
        XCTAssertEqual(app.buttons["receive.check.retake"].label, "Choose another")
        XCTAssertFalse(app.staticTexts["invoice.title"].exists, "Nothing goes on before an answer")
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "receive-check"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["receive.check.useAnyway"].tap()
        XCTAssertTrue(app.staticTexts["invoice.title"].waitForExistence(timeout: 5), "Review invoice did not open")
    }

    @MainActor
    func testClosingTheCheckDropsTheImage() throws {
        let app = try uploadDarkImage()
        let title = app.staticTexts["receive.check.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "The check's sheet did not open")
        let bottom = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: bottom)
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: title)
        wait(for: [closed], timeout: 5)
        XCTAssertTrue(app.buttons["receive.upload"].isHittable, "Receive delivery is not back")
        XCTAssertFalse(app.staticTexts["invoice.title"].exists, "The image went on")
    }
}
