import XCTest

/// Clinic settings (f33) from Account: Save waits for a change and says "Settings saved"; leaving with changes asks
/// "Discard changes?" first.
final class ClinicSettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAnAdminChangesTheExpiryWarningAndSaves() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openSettings(in: app)

        XCTAssertEqual(app.textFields["settings.clinicName"].value as? String, "Smile Dental")
        let save = app.buttons["settings.save"]
        XCTAssertFalse(save.isEnabled, "Save before any change")
        let warning = app.buttons["settings.expiryWarning"]
        XCTAssertEqual(warning.value as? String, "30, 60 and 90 days")
        warning.tap()
        let ninety = app.buttons["90 days only"]
        XCTAssertTrue(ninety.waitForExistence(timeout: 5), "The choices did not open")
        ninety.tap()
        XCTAssertEqual(warning.value as? String, "90 days only")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["Settings saved"].waitForExistence(timeout: 5), "No toast")
        XCTAssertFalse(save.isEnabled, "Saved is the new starting point")
    }

    /// A new name reaches the screens already open: Account's card reads it after Back (MS-139 review).
    @MainActor
    func testARenamedClinicShowsOnAccount() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openSettings(in: app)

        let name = app.textFields["settings.clinicName"]
        name.tap()
        name.typeText(" Group")
        app.buttons["settings.save"].tap()
        XCTAssertTrue(app.staticTexts["Settings saved"].waitForExistence(timeout: 5), "No toast")
        let back = app.buttons["settings.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        let user = app.descendants(matching: .any)["more.user"]
        XCTAssertTrue(user.waitForExistence(timeout: 5), "Back did not return to Account")
        XCTAssertTrue(user.label.contains("Admin · Smile Dental Group"), "The card reads \(user.label)")
    }

    @MainActor
    func testLeavingWithChangesAsksFirst() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openSettings(in: app)

        app.descendants(matching: .any)["settings.digest"].tap()
        app.buttons["settings.back"].tap()
        let keep = app.buttons["settings.keepEditing"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "No question before leaving")
        keep.tap()
        XCTAssertTrue(keep.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["settings.title"].exists, "Keep editing left")

        app.buttons["settings.back"].tap()
        let discard = app.buttons["settings.discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertTrue(app.buttons["more.settings"].waitForExistence(timeout: 5), "Discard did not go back to Account")
    }

    @MainActor
    private func openSettings(in app: XCUIApplication) {
        let account = app.buttons["home.header.account"]
        XCTAssertTrue(account.waitForExistence(timeout: 5), "Home has no account button")
        account.tap()
        let settings = app.buttons["more.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "Account did not open")
        settings.tap()
        let title = app.staticTexts["settings.title"]
        if !title.waitForExistence(timeout: 2) { settings.tap() }
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Clinic settings did not open")
        XCTAssertTrue(app.textFields["settings.clinicName"].waitForExistence(timeout: 5), "The settings did not load")
    }
}
