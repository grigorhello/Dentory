import Foundation

/// Ends the member's session on this device (MS-137, Account › Sign out).
@MainActor
protocol SigningOut {
    /// Changes made offline that have not reached the server yet; signing out discards them.
    var unsyncedChangeCount: Int { get }

    func signOut() async
}
