import Foundation

/// Signs out and leaves nothing of the clinic on the device: the cached answers and the writes still waiting for a
/// connection go first, so the next person to sign in here never sees them and never sends them under their own
/// name; the device stops receiving the member's pushes (MS-144); then the session ends and the app returns to
/// Sign in.
@MainActor
struct DeviceSignOut: SigningOut {
    let sessionStore: SessionStore
    let cache: ResponseCaching
    let writes: PendingWriteQueue
    let push: PushNotifications

    var unsyncedChangeCount: Int { writes.count }

    func signOut() async {
        cache.removeAll()
        writes.removeAll()
        // While the session still lets the server know whose device this is.
        await push.signOut()
        await sessionStore.signOut()
        // A read still in flight when the cache was cleared may have written its answer back since.
        cache.removeAll()
    }
}
