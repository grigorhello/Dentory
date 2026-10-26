import XCTest

/// Sign-up → clinic → invite (MS-136): a new admin account through Supabase Auth, a clinic through `clinic_create`, and
/// a teammate invited through `invite_member` (on the local stack the email goes to the function's log, where `make
/// invite-links` finds its link); the new clinic's Home opens, and Team lists the teammate as invited. Each run signs
/// up new addresses, so it never meets an earlier run's.
final class SignUpE2ETests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testANewAdminSetsUpAClinicAndInvitesATeammate() {
        let run = UUID().uuidString.prefix(8).lowercased()
        let admin = "owner-\(run)@e2e.dentory.test"
        let teammate = "assistant-\(run)@e2e.dentory.test"
        let app = E2E.launch()

        app.descendants(matching: .any)["signin.signUpAdmin"].tap()
        let continueButton = app.buttons["onboard.continue"]
        continueButton.appears("Create your admin account did not open")
        app.textFields["onboard.name"].firstMatch.tap()
        app.typeText("Dr. Lena Park")
        app.textFields["onboard.email"].firstMatch.tap()
        app.typeText(admin)
        app.secureTextFields["onboard.password"].firstMatch.tap()
        app.typeText(E2E.password)
        continueButton.tap()
        app.declineSavingPassword()

        let clinicName = app.textFields["onboard.clinicName"].firstMatch
        clinicName.appears("Create your clinic did not open")
        clinicName.tap()
        app.typeText("Lakeview Dental \(run)")
        app.textFields["onboard.city"].firstMatch.tap()
        app.typeText("Ottawa")
        app.buttons["onboard.continue"].tap()

        let invite = app.textFields["onboard.inviteRow[0].email"].firstMatch
        invite.appears("Invite your team did not open")
        invite.tap()
        app.typeText(teammate)
        app.buttons["onboard.sendInvites"].tap()

        app.staticTexts["Lakeview Dental \(run)"].appears("Home did not open")
        E2E.dismissNotificationsExplainer(in: app)
        app.buttons["home.header.account"].tap()
        let team = app.buttons["more.team"]
        team.appears("Account did not open")
        team.tap()
        let invited = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", teammate)).firstMatch
        invited.appears("The teammate is not on Team")
        XCTAssertTrue(invited.label.contains("Invited"), "The teammate reads \(invited.label)")
        let owner = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Dr. Lena Park")).firstMatch
        XCTAssertTrue(owner.label.contains("Admin"), "The new admin reads \(owner.label)")
    }
}
