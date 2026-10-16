import XCTest

final class SignInUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testSigningInAsTheDemoAdminLandsOnHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-signedOut"]
        app.launch()

        let email = app.textFields["signin.email"].firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 5), "Sign in did not appear")
        let submit = app.buttons["signin.submit"]
        XCTAssertFalse(submit.isEnabled, "Sign in is enabled before the fields are filled")

        // The component carries the id, so focus is checked on the app, not the element.
        email.tap()
        app.typeText("sarah@smiledental.ca")
        let password = app.secureTextFields["signin.password"].firstMatch
        password.tap()
        app.typeText("wrong")
        XCTAssertTrue(submit.isEnabled)
        submit.tap()
        XCTAssertTrue(app.staticTexts["Wrong password."].waitForExistence(timeout: 5), "No inline password error")

        password.tap()
        app.typeText("smiledental")
        XCTAssertTrue(app.staticTexts["Wrong password."].waitForNonExistence(timeout: 2), "Typing did not clear it")
        submit.tap()
        XCTAssertTrue(app.staticTexts["Smile Dental"].waitForExistence(timeout: 8), "Home did not appear")
    }
}
