import Foundation
@testable import Dentory

/// Counts sign-outs instead of ending a session.
@MainActor
final class FakeSigningOut: SigningOut {
    var unsyncedChangeCount = 0
    private(set) var signOutCount = 0

    func signOut() async {
        signOutCount += 1
    }
}
