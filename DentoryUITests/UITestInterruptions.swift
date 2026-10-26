import XCTest

/// The UI test bundles' principal class (`NSPrincipalClass` in `project.yml`, for `DentoryUITests` and
/// `DentoryE2ETests`): XCTest creates it on the main thread as the bundle loads, and it gives every test the handlers for
/// what iOS puts over the app uninvited, so the flows run on any iOS the simulators have.
@MainActor
@objc(DentoryUITestInterruptions)
final class UITestInterruptions: NSObject, @preconcurrency XCTestObservation {
    override init() {
        super.init()
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testCaseWillStart(_ testCase: XCTestCase) {
        // iOS 26 offers to save a password once its field leaves the screen (sign-up, Sign in, Join, Set a new
        // password), and its sheet covers the next screen until Not Now (MS-136 audit). Earlier iOS does not ask.
        _ = testCase.addUIInterruptionMonitor(withDescription: "Save Password?") { sheet in
            let notNow = sheet.buttons["Not Now"]
            guard notNow.exists else { return false }
            notNow.tap()
            return true
        }
    }
}
