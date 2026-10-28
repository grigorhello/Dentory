import XCTest

/// MS-113: Forgot password on Sign in, the reset link's Set a new password, and an expired link; security review F4:
/// the link names its account, leaves the signed-in member signed in until the password is saved, and has a way out.
/// Runs on the preview doubles: `demo-reset` is Sarah's link that works, any other token hash reads as expired.
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
        XCTAssertTrue(
            app.staticTexts["Choose a password for sarah@smiledental.ca"].exists, "The link's address is not shown"
        )
        XCTAssertTrue(app.buttons["setPassword.signIn"].exists, "The ready state has no way back to Sign in")
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

    @MainActor
    func testALinkOpenedOverResetPasswordLeavesToSignInItself() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-signedOut"]
        app.launch()

        let forgot = app.buttons["signin.forgot"]
        XCTAssertTrue(forgot.waitForExistence(timeout: 5), "Sign in did not appear")
        forgot.tap()
        XCTAssertTrue(app.staticTexts["resetPassword.title"].waitForExistence(timeout: 5), "Reset password missing")

        app.open(try XCTUnwrap(URL(string: "dentory://reset-password?token_hash=old-link")))
        XCTAssertTrue(app.staticTexts["This link has expired"].waitForExistence(timeout: 5), "The link did not open")
        app.buttons["setPassword.signIn"].tap()
        XCTAssertTrue(app.buttons["signin.submit"].waitForExistence(timeout: 5), "Sign in did not appear")
        XCTAssertFalse(app.staticTexts["resetPassword.title"].exists, "Reset password was left pushed on Sign in")
    }

    @MainActor
    func testANewerLinkReplacesTheExpiredOne() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-signedOut", "-resetPassword", "old-link"]
        app.launch()

        XCTAssertTrue(app.staticTexts["This link has expired"].waitForExistence(timeout: 5), "No expired state")
        app.buttons["setPassword.sendNew"].tap()
        XCTAssertTrue(app.staticTexts["resetPassword.title"].waitForExistence(timeout: 5), "Reset password missing")

        app.open(try XCTUnwrap(URL(string: "dentory://reset-password?token_hash=demo-reset")))
        XCTAssertTrue(app.staticTexts["Set a new password"].waitForExistence(timeout: 5), "The new link is hidden")
        XCTAssertFalse(app.staticTexts["resetPassword.title"].exists, "Reset password is still on top")
    }

    @MainActor
    func testTheReadyStateLeadsBackToSignIn() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-signedOut", "-resetPassword", "demo-reset"]
        app.launch()

        let signIn = app.buttons["setPassword.signIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5), "The ready state has no way back to Sign in")
        XCTAssertEqual(signIn.label, "Sign in")
        signIn.tap()
        XCTAssertTrue(app.buttons["signin.submit"].waitForExistence(timeout: 5), "Sign in did not appear")
    }

    /// F4: a link for another account opened on Michael's device leaves him signed in; Cancel returns to his Home.
    @MainActor
    func testALinkForAnotherAccountLeavesTheSignedInMemberSignedIn() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff", "-resetPassword", "demo-reset"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Choose a password for sarah@smiledental.ca"].waitForExistence(timeout: 5),
            "The link's address is not shown"
        )
        XCTAssertFalse(app.buttons["setPassword.signIn"].exists, "Sign in shows while Michael is signed in")
        let cancel = app.buttons["setPassword.cancel"]
        XCTAssertTrue(cancel.exists, "The ready state has no way back")
        cancel.tap()

        XCTAssertTrue(app.staticTexts["Smile Dental"].waitForExistence(timeout: 8), "Home did not appear")
        XCTAssertFalse(
            app.descendants(matching: .any)["home.receive"].exists, "Home is not Michael's: Staff have no Receive"
        )
    }

    /// F4: saving the password over Michael's session signs Sarah in only then, after Sign out's clean-up.
    @MainActor
    func testSavingALinkForAnotherAccountSignsThatAccountIn() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff", "-resetPassword", "demo-reset"]
        app.launch()

        let field = app.secureTextFields["setPassword.password"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Set a new password missing")
        field.tap()
        app.typeText("newpassword")
        app.buttons["setPassword.save"].tap()

        let receive = app.descendants(matching: .any)["home.receive"]
        XCTAssertTrue(receive.waitForExistence(timeout: 8), "Home is not Sarah's: an admin sees Receive delivery")
    }
}
