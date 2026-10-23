import SwiftUI

/// Checks the signed-in member against the server as a screen loads (MS-138: a member removed from the clinic is
/// signed out on their next request). `RootView` sets it to the session's check, which runs at most once a minute;
/// previews and screens outside the tabs keep the default, which does nothing.
struct MembershipCheckAction: Sendable {
    private let check: @MainActor @Sendable () async -> Void

    init(_ check: @escaping @MainActor @Sendable () async -> Void) {
        self.check = check
    }

    @MainActor
    func callAsFunction() async {
        await check()
    }
}

private struct MembershipCheckKey: EnvironmentKey {
    static let defaultValue = MembershipCheckAction {}
}

extension EnvironmentValues {
    var membershipCheck: MembershipCheckAction {
        get { self[MembershipCheckKey.self] }
        set { self[MembershipCheckKey.self] = newValue }
    }
}
