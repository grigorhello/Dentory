import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAdminSignUpLandsOnHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-signedOut"]
        app.launch()
        signUpANewClinic(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["toast"].waitForExistence(timeout: 3), "No toast")
    }

    /// Return moves from Full name to Work email to Password, as on Sign in and Join, and continues from Password
    /// (MS-136 audit V-04).
    @MainActor
    func testReturnMovesThroughStepOneAndContinues() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-signedOut"]
        app.launch()
        let signUp = app.descendants(matching: .any)["signin.signUpAdmin"]
        XCTAssertTrue(signUp.waitForExistence(timeout: 5))
        signUp.tap()

        let name = app.textFields["onboard.name"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5), "Step 1 did not appear")
        name.tap()
        app.typeText("Dr. Sarah Mitchell\n")
        app.typeText("owner@newclinic.ca\n")
        XCTAssertEqual(app.textFields["onboard.email"].firstMatch.value as? String, "owner@newclinic.ca")
        app.typeText("smiledental\n")
        XCTAssertTrue(app.staticTexts["Create your clinic"].waitForExistence(timeout: 5), "Return did not continue")
    }

    /// A new admin who sets up the clinic and signs out hands the device over on Sign in, not on sign-up's first step
    /// (MS-137 review).
    @MainActor
    func testSigningOutAfterSignUpShowsSignIn() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-signedOut"]
        app.launch()
        signUpANewClinic(in: app)

        app.buttons["home.header.account"].tap()
        let signOut = app.buttons["more.signOut"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 5), "Account did not open")
        signOut.tap()
        let confirm = app.buttons["signOut.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["signin.submit"].waitForExistence(timeout: 5), "Sign in did not show")
        XCTAssertFalse(app.staticTexts["Create your admin account"].exists, "Sign-up's first step came back")
    }

    /// Admin sign-up's three steps, ending on the new clinic's Home.
    @MainActor
    private func signUpANewClinic(in app: XCUIApplication) {
        let signUp = app.descendants(matching: .any)["signin.signUpAdmin"]
        XCTAssertTrue(signUp.waitForExistence(timeout: 5))
        signUp.tap()

        XCTAssertTrue(app.staticTexts["Create your admin account"].waitForExistence(timeout: 5))
        let continueButton = app.buttons["onboard.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5), "No Continue button")
        XCTAssertFalse(continueButton.isEnabled)
        app.textFields["onboard.name"].firstMatch.tap()
        app.typeText("Dr. Sarah Mitchell")
        app.textFields["onboard.email"].firstMatch.tap()
        app.typeText("owner@newclinic.ca")
        app.secureTextFields["onboard.password"].firstMatch.tap()
        app.typeText("smiledental")
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        XCTAssertTrue(app.staticTexts["Create your clinic"].waitForExistence(timeout: 5), "Step 2 did not appear")
        app.textFields["onboard.clinicName"].firstMatch.tap()
        app.typeText("New Clinic")
        app.textFields["onboard.city"].firstMatch.tap()
        app.typeText("Toronto")
        app.buttons["onboard.continue"].tap()

        XCTAssertTrue(app.staticTexts["Invite your team"].waitForExistence(timeout: 5), "Step 3 did not appear")
        app.textFields["onboard.inviteRow[0].email"].firstMatch.tap()
        app.typeText("priya@newclinic.ca")
        app.buttons["onboard.sendInvites"].tap()

        XCTAssertTrue(app.staticTexts["New Clinic"].waitForExistence(timeout: 8), "Home did not appear")
    }
}
