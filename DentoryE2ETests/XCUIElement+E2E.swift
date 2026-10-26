import XCTest

extension XCUIElement {
    /// Fails the flow with `message` unless the element shows within `E2E.patience`.
    @MainActor
    func appears(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitForExistence(timeout: E2E.patience), message, file: file, line: line)
    }
}
