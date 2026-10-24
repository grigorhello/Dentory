import Foundation

/// A logo picked in Clinic settings whose upload failed, kept outside the screen (MS-139): a new clinic name, currency
/// or time zone rebuilds the open screens when the app comes back to the foreground, and the picked logo waits here for
/// Save to try it again instead of being dropped with the old screen.
nonisolated final class PendingClinicLogo: @unchecked Sendable {
    private var logos: [UUID: Data] = [:]
    private let lock = NSLock()

    func logo(for clinicID: UUID) -> Data? {
        lock.withLock { logos[clinicID] }
    }

    /// Keeps the logo waiting for its retry, or forgets it with nil.
    func keep(_ data: Data?, for clinicID: UUID) {
        lock.withLock { logos[clinicID] = data }
    }

    /// Sign out: the next person starts without it.
    func removeAll() {
        lock.withLock { logos.removeAll() }
    }
}
