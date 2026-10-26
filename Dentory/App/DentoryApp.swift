import SwiftUI

@main
struct DentoryApp: App {
    /// The APNs token and tapped notifications arrive through UIKit's delegate (MS-144).
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let dependencies: AppDependencies
    private let startsOnSignUp: Bool
    /// `-invite <token>` opens the Join screen for that invitation (UI tests use the preview's `demo-invite`).
    private let invitationToken: String?
    /// `-resetPassword <tokenHash>` opens Set a new password for that reset link (UI tests use `demo-reset`).
    private let resetTokenHash: String?
    /// `-signedOut` on a Debug build without `-uiTesting`: the device signs out before the session is restored, as Sign
    /// out leaves it, so each end-to-end flow on the local stack starts on Sign in (MS-136).
    private let signsOutFirst: Bool
    @State private var sessionStore: SessionStore

    init() {
        // `-uiTesting` runs the app on the preview doubles: no network, a signed-in demo admin.
        // `-offline` with it makes the network monitor report no connection; `-signedOut` starts on Sign in;
        // `-staff` signs in as the Staff member; `-onboarding account|clinic|invite` opens admin sign-up there;
        // `-invite <token>` opens the Join screen of an invitation; `-resetPassword <tokenHash>` opens Set a new
        // password; `-tab inventory` and `-inventoryFilter Low` open a tab and a chip (RootView); `-demoHistoryRows 120`
        // adds older rows to Activity's History, for paging; `-pushExplainer` offers notifications after sign-in,
        // which the other runs skip. Without `-uiTesting` a Debug build talks to the local stack, and the end-to-end
        // flows (MS-136) launch it with `-signedOut` and `-receiveFile <path>` (ReceiveView).
        let arguments = ProcessInfo.processInfo.arguments
        let onboarding = UserDefaults.standard.string(forKey: "onboarding")
        startsOnSignUp = onboarding == "account"
        invitationToken = UserDefaults.standard.string(forKey: "invite")
        resetTokenHash = UserDefaults.standard.string(forKey: "resetPassword")
        let isDemo = arguments.contains("-uiTesting")
        #if DEBUG
        signsOutFirst = !isDemo && arguments.contains("-signedOut")
        #else
        signsOutFirst = false
        #endif
        let dependencies = isDemo
            ? AppDependencies.preview(
                signedIn: !arguments.contains("-signedOut") && onboarding != "account",
                isConnected: !arguments.contains("-offline"),
                role: arguments.contains("-staff") ? .staff : .admin,
                onboarding: onboarding,
                offersPush: arguments.contains("-pushExplainer")
            )
            : AppDependencies.live()
        self.dependencies = dependencies
        _sessionStore = State(initialValue: SessionStore(
            auth: dependencies.auth, clearDevice: { dependencies.clearClinicData() }, analytics: dependencies.analytics
        ))
        dependencies.reporter.start()
        dependencies.analytics.start()
        dependencies.writes.startWatchingNetwork()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                sessionStore: sessionStore,
                startsOnSignUp: startsOnSignUp,
                invitationToken: invitationToken,
                resetTokenHash: resetTokenHash
            )
            .environment(\.appDependencies, dependencies)
            .task {
                appDelegate.push = dependencies.push
                if signsOutFirst {
                    dependencies.clearClinicData()
                    dependencies.onboardingProgress.setPendingInviteClinicID(nil)
                    try? await dependencies.auth.signOut()
                }
                await sessionStore.restore()
            }
        }
    }
}
