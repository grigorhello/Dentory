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
        XCTAssertTrue(app.descendants(matching: .any)["toast"].waitForExistence(timeout: 3), "No toast")
    }
}
