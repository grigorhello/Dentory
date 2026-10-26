import XCTest

extension XCUIApplication {
    /// Not Now on iOS 26's "Save Password?", which it offers once a password field leaves the screen (sign-up's first
    /// step, Sign in) and whose sheet covers the next screen until answered. It is the app's own sheet, so XCTest's
    /// interruption monitors pass it by; a flow that taps on after a password calls this. iOS 18 does not offer it, so
    /// there it returns at once (`DentoryUITests` and `DentoryE2ETests` share this file).
    @MainActor
    func declineSavingPassword() {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 else { return }
        let notNow = sheets.buttons["Not Now"]
        guard notNow.waitForExistence(timeout: 5) else { return }
        // The sheet slides in, and a tap before it settles is lost: tap until it goes.
        for _ in 1...5 {
            if notNow.isHittable { notNow.tap() }
            if notNow.waitForNonExistence(timeout: 1) { return }
        }
        XCTFail("Save Password? stayed")
    }
}
