import Foundation
@testable import Dentory

/// Counts sign-outs instead of ending a session.
@MainActor
final class FakeSigningOut: SigningOut {
    var unsyncedChangeCount = 0
    private(set) var signOutCount = 0
    /// Runs inside `signOut()`, so a test can see what had happened by then.
    var onSignOut: (() -> Void)?

    func signOut() async {
        signOutCount += 1
        onSignOut?()
    }
}
