import XCTest

final class InvitationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testJoiningFromAnInvitationLinkLandsOnHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-signedOut", "-invite", "demo-invite"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Join Smile Dental"].waitForExistence(timeout: 5), "No Join screen")
        XCTAssertTrue(app.staticTexts["Sarah Mitchell invited you as Staff. Set a password to finish."].exists)
        let join = app.buttons["invite.submit"]
        XCTAssertTrue(join.waitForExistence(timeout: 5), "No Join button")
        XCTAssertFalse(join.isEnabled, "Join is enabled before the fields are filled")

        app.textFields["invite.name"].firstMatch.tap()
        // Return moves to the password, as on Sign in; wait for the focus before typing into it.
        app.typeText("Priya Patel\n")
        let password = app.secureTextFields["invite.password"].firstMatch
        let focused = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: password
        )
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 3), .completed, "The password field has no focus")
        app.typeText("smiledental")
        XCTAssertTrue(join.isEnabled, "Join stays disabled: name and password were not both filled")
        join.tap()

        XCTAssertTrue(app.staticTexts["Smile Dental"].waitForExistence(timeout: 8), "Home did not appear")
    }

    @MainActor
    func testAnExpiredInvitationOffersSignIn() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-signedOut", "-invite", "old-token"]
        app.launch()

        XCTAssertTrue(app.staticTexts["This invitation has expired"].waitForExistence(timeout: 5), "No expired state")
        XCTAssertTrue(app.staticTexts["Ask your admin to resend."].exists)
        XCTAssertFalse(app.buttons["invite.submit"].exists, "Join must not show for an expired invitation")
        app.buttons["invite.signIn"].tap()
        XCTAssertTrue(app.textFields["signin.email"].waitForExistence(timeout: 5), "Sign in did not appear")
    }
}
