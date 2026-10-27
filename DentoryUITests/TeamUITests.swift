import XCTest

/// Team (f31 Admin, f32 Staff) from Account: the demo clinic's people, an invitation sent, a role changed, a person
/// removed after the question, the last admin kept, and Staff reading the list only.
final class TeamUITests: XCTestCase {
    private let sarah = "team.member[00000000-0000-4000-8000-0000000000a1]"
    private let daniel = "team.member[00000000-0000-4000-8000-0000000000a2]"
    private let michael = "team.member[00000000-0000-4000-8000-0000000000a3]"
    private let priya = "team.member[00000000-0000-4000-8000-000000000ba4]"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAnAdminInvitesATeammate() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openTeam(in: app)

        for id in [sarah, daniel, michael, priya] {
            XCTAssertTrue(app.buttons[id].exists, "Missing \(id)")
        }
        let priyaRow = app.buttons[priya]
        XCTAssertTrue(priyaRow.label.contains("Invited\u{00A0}· Oct 1"), "Priya reads \(priyaRow.label)")
        XCTAssertTrue(app.buttons[daniel].label.contains("Admin"))

        app.buttons["team.invite"].tap()
        let email = app.textFields["invite.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5), "No invite sheet")
        XCTAssertFalse(app.buttons["invite.send"].isEnabled, "Send waits for an address")
        tapWhenReady(app.textFields["invite.name"])
        app.typeText("Anna Lee")
        tapWhenReady(email)
        app.typeText("michael@smiledental.ca")
        tapWhenReady(app.buttons["invite.send"])
        let duplicate = app.staticTexts["michael@smiledental.ca is already on the team."]
        XCTAssertTrue(duplicate.waitForExistence(timeout: 5), "An address on the team is not refused")

        tapWhenReady(email)
        email.clearText()
        app.typeText("anna@smiledental.ca")
        tapWhenReady(app.buttons["invite.send"])
        XCTAssertTrue(app.descendants(matching: .any)["toast"].waitForExistence(timeout: 5), "No toast")
        let anna = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "anna@smiledental.ca")).firstMatch
        XCTAssertTrue(anna.waitForExistence(timeout: 5), "The invitation is not listed")
        XCTAssertTrue(anna.label.contains("Invited"), "Anna reads \(anna.label)")
    }

    @MainActor
    func testAnAdminChangesARoleAndRemovesSomeoneButKeepsAnAdmin() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openTeam(in: app)

        app.buttons[michael].tap()
        // iOS 26 draws a dialog's action as a button inside a button, both with its id.
        let toAdmin = app.buttons["\(michael).menu.role"].firstMatch
        XCTAssertTrue(toAdmin.waitForExistence(timeout: 5), "No menu")
        XCTAssertEqual(toAdmin.label, "Change role to Admin")
        toAdmin.tap()
        let michaelAdmin = NSPredicate(format: "label CONTAINS %@", "Admin")
        wait(for: [expectation(for: michaelAdmin, evaluatedWith: app.buttons[michael])], timeout: 5)

        tapWhenReady(app.buttons[daniel])
        XCTAssertEqual(app.buttons["\(daniel).menu.remove"].firstMatch.label, "Remove from clinic")
        tapWhenReady(app.buttons["\(daniel).menu.remove"].firstMatch)
        let question = app.staticTexts["team.remove.title"]
        XCTAssertTrue(question.waitForExistence(timeout: 5), "No question before removing")
        XCTAssertEqual(question.label, "Remove Dr. Daniel Kim?")
        tapWhenReady(app.buttons["team.remove.keep"])
        XCTAssertTrue(question.waitForNonExistence(timeout: 5), "Keep did not close it")
        XCTAssertTrue(app.buttons[daniel].exists, "Keep removed him")
        tapWhenReady(app.buttons[daniel])
        tapWhenReady(app.buttons["Remove from clinic"])
        tapWhenReady(app.buttons["team.remove.confirm"])
        XCTAssertTrue(app.buttons[daniel].waitForNonExistence(timeout: 5), "Remove kept him")

        // Michael and Sarah are the admins now; Michael goes back to Staff, and Sarah, the last one, stays.
        tapWhenReady(app.buttons[michael])
        tapWhenReady(app.buttons["Change role to Staff"])
        let michaelStaff = NSPredicate(format: "label CONTAINS %@", "Staff")
        wait(for: [expectation(for: michaelStaff, evaluatedWith: app.buttons[michael])], timeout: 5)
        tapWhenReady(app.buttons[sarah])
        tapWhenReady(app.buttons["Change role to Staff"])
        XCTAssertTrue(app.staticTexts["A clinic needs at least one admin."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testStaffReadTheTeamOnly() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-staff"]
        app.launch()
        openTeam(in: app)

        let row = app.descendants(matching: .any)[michael]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No rows for Staff")
        XCTAssertFalse(app.buttons["team.invite"].exists, "Staff see Invite")
        row.tap()
        XCTAssertFalse(app.buttons["\(michael).menu.remove"].waitForExistence(timeout: 2), "Staff opened a menu")
    }

    /// Taps once the element is on screen and can take the tap: a sheet or a dialog still sliding in drops it.
    @MainActor
    private func tapWhenReady(_ element: XCUIElement) {
        let ready = NSPredicate(format: "exists == true AND hittable == true")
        wait(for: [expectation(for: ready, evaluatedWith: element)], timeout: 5)
        element.tap()
    }

    @MainActor
    private func openTeam(in app: XCUIApplication) {
        let account = app.buttons["home.header.account"]
        XCTAssertTrue(account.waitForExistence(timeout: 5), "Home has no account button")
        account.tap()
        let team = app.buttons["more.team"]
        XCTAssertTrue(team.waitForExistence(timeout: 5), "Account did not open")
        team.tap()
        let title = app.staticTexts["team.title"]
        if !title.waitForExistence(timeout: 2) { team.tap() }
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Team did not open")
        XCTAssertTrue(app.descendants(matching: .any)[michael].waitForExistence(timeout: 5), "The team did not load")
    }
}

private extension XCUIElement {
    /// Deletes what a focused text field holds.
    @MainActor
    func clearText() {
        guard let text = value as? String, !text.isEmpty else { return }
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count))
    }
}
