import Foundation

/// Signs out and leaves nothing of the clinic on the device: the cached answers and the writes still waiting for a
/// connection go first, so the next person to sign in here never sees them and never sends them under their own
/// name, then the session ends and the app returns to Sign in. The device's push token joins this with MS-144.
@MainActor
struct DeviceSignOut: SigningOut {
    let sessionStore: SessionStore
    let cache: ResponseCaching
    let writes: PendingWriteQueue

    var unsyncedChangeCount: Int { writes.count }

    func signOut() async {
        cache.removeAll()
        writes.removeAll()
        await sessionStore.signOut()
        // A read still in flight when the cache was cleared may have written its answer back since.
        cache.removeAll()
    }
}
