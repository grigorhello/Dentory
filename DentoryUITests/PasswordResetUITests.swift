import XCTest

/// MS-113: Forgot password on Sign in, the reset link's Set a new password, and an expired link. Runs on the
/// preview doubles: `demo-reset` is the link that works, any other token hash reads as expired.
final class PasswordResetUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testForgotPasswordSendsALinkWithTheSameAnswerForAnyAddress() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-signedOut"]
        app.launch()

        let email = app.textFields["signin.email"].firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 5), "Sign in did not appear")
        email.tap()
        app.typeText("sarah@smiledental.ca")
        app.buttons["signin.forgot"].tap()

        let title = app.staticTexts["resetPassword.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Reset password did not open")
        XCTAssertTrue(app.staticTexts["We'll email you a link to set a new password."].exists, "No caption")
        let resetEmail = app.textFields["resetPassword.email"].firstMatch
        XCTAssertEqual(resetEmail.value as? String, "sarah@smiledental.ca", "The email is not prefilled from Sign in")
        app.buttons["resetPassword.send"].tap()
        let sent = app.staticTexts["If an account exists for sarah@smiledental.ca, a link is on its way."]
        XCTAssertTrue(sent.waitForExistence(timeout: 5), "No confirmation")

        app.buttons["resetPassword.back"].tap()
        XCTAssertTrue(app.buttons["signin.submit"].waitForExistence(timeout: 5), "Back did not return to Sign in")
    }

    @MainActor
    func testAResetLinkSetsANewPasswordAndLandsOnHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-signedOut", "-resetPassword", "demo-reset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Set a new password"].waitForExistence(timeout: 5), "Set a new password missing")
        let save = app.buttons["setPassword.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No Save password button")
        XCTAssertFalse(save.isEnabled, "Save password is enabled before a password is typed")

        app.secureTextFields["setPassword.password"].firstMatch.tap()
        app.typeText("short")
        XCTAssertFalse(save.isEnabled, "Save password is enabled under 8 characters")
        app.typeText("enough")
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(app.staticTexts["Smile Dental"].waitForExistence(timeout: 8), "Home did not appear")
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 3), "No toast after saving")
        XCTAssertTrue(toast.staticTexts["Password updated"].exists, "The toast does not say Password updated")
    }

    @MainActor
    func testAnExpiredResetLinkOffersANewOneAndSignIn() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-signedOut", "-resetPassword", "old-link"]
        app.launch()

        XCTAssertTrue(app.staticTexts["This link has expired"].waitForExistence(timeout: 5), "No expired state")
        XCTAssertTrue(app.staticTexts["Send a new one."].exists)
        app.buttons["setPassword.sendNew"].tap()
        let resetTitle = app.staticTexts["resetPassword.title"]
        XCTAssertTrue(resetTitle.waitForExistence(timeout: 5), "Reset password did not open")

        app.buttons["resetPassword.back"].tap()
        let signIn = app.buttons["setPassword.signIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5), "Back did not return to the expired link")
        signIn.tap()
        XCTAssertTrue(app.buttons["signin.submit"].waitForExistence(timeout: 5), "Sign in did not appear")
    }
}
