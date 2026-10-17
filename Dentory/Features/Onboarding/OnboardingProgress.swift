import Foundation

/// Remembers that step 3 (invite team) is still due for a clinic, so a relaunch after step 2 resumes
/// there instead of landing on Home (MS-111 acceptance).
protocol OnboardingProgressStoring: AnyObject, Sendable {
    func pendingInviteClinicID() -> UUID?
    func setPendingInviteClinicID(_ id: UUID?)
}

final class UserDefaultsOnboardingProgress: OnboardingProgressStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "onboarding.pendingInviteClinicID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func pendingInviteClinicID() -> UUID? {
        defaults.string(forKey: key).flatMap(UUID.init(uuidString:))
    }

    func setPendingInviteClinicID(_ id: UUID?) {
        defaults.set(id?.uuidString, forKey: key)
    }
}

final class InMemoryOnboardingProgress: OnboardingProgressStoring, @unchecked Sendable {
    private var id: UUID?
    private let lock = NSLock()

    init(pending: UUID? = nil) {
        id = pending
    }

    func pendingInviteClinicID() -> UUID? { lock.withLock { id } }
    func setPendingInviteClinicID(_ id: UUID?) { lock.withLock { self.id = id } }
}
