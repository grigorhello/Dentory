import XCTest

/// Account (f29 Admin, f30 Staff) from Home's account button: the user card, the rows each role sees, Team's
/// placeholder, and Sign out, which asks first and ends on Sign in.
final class AccountUITests: XCTestCase {
    private let adminRows = ["more.settings", "more.billing", "more.export"]

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAdminSeesEveryRowAndSignsOut() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openAccount(in: app)

        let user = app.descendants(matching: .any)["more.user"]
        XCTAssertTrue(user.label.contains("Sarah Mitchell"), "The card reads \(user.label)")
        XCTAssertTrue(user.label.contains("Admin · Smile Dental"), "The card reads \(user.label)")
        for id in ["more.team", "more.help", "more.signOut"] + adminRows {
            XCTAssertTrue(app.buttons[id].exists, "Missing \(id)")
        }
        let team = app.buttons["more.team"]
        XCTAssertTrue(team.label.contains("3 people"), "Team reads \(team.label)")

        // Team arrives with MS-138; its placeholder is pushed and Back returns. A tap while Account is still sliding
        // in can be dropped by the navigation stack, so a second one follows if nothing opened.
        team.tap()
        let teamTitle = app.staticTexts["team.title"]
        if !teamTitle.waitForExistence(timeout: 2) { team.tap() }
        XCTAssertTrue(teamTitle.waitForExistence(timeout: 5), "Team did not open")
        app.buttons["team.back"].tap()

        // Keep changes nothing; Sign out ends on Sign in.
        app.buttons["more.signOut"].tap()
        XCTAssertTrue(app.staticTexts["signOut.title"].waitForExistence(timeout: 5), "No confirmation")
        XCTAssertEqual(app.staticTexts["signOut.message"].label, "You can sign in again with your email.")
        app.buttons["signOut.keep"].tap()
        XCTAssertTrue(app.staticTexts["signOut.title"].waitForNonExistence(timeout: 5), "Keep did not close it")
        XCTAssertTrue(app.staticTexts["more.title"].exists)

        app.buttons["more.signOut"].tap()
        let confirm = app.buttons["signOut.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["signin.submit"].waitForExistence(timeout: 5), "Sign in did not show")
    }

    @MainActor
    func testStaffSeeTeamHelpAndSignOutOnly() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff"]
        app.launch()
        openAccount(in: app)

        let user = app.descendants(matching: .any)["more.user"]
        XCTAssertTrue(user.label.contains("Michael Reyes"), "The card reads \(user.label)")
        XCTAssertTrue(user.label.contains("Staff · Smile Dental"), "The card reads \(user.label)")
        for id in ["more.team", "more.help", "more.signOut"] {
            XCTAssertTrue(app.buttons[id].exists, "Missing \(id)")
        }
        for id in adminRows {
            XCTAssertFalse(app.buttons[id].exists, "Staff see \(id)")
        }
    }

    @MainActor
    private func openAccount(in app: XCUIApplication) {
        let account = app.buttons["home.header.account"]
        XCTAssertTrue(account.waitForExistence(timeout: 5), "Home has no account button")
        account.tap()
        XCTAssertTrue(app.staticTexts["more.title"].waitForExistence(timeout: 5), "Account did not open")
    }
}
