import Foundation

/// The explainer's last offer for the app, kept across launches.
final class UserDefaultsPushExplainerStore: PushExplainerStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "push.explainerOfferedAt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastOffered: Date? {
        get { defaults.object(forKey: key) as? Date }
        set { defaults.set(newValue, forKey: key) }
    }
}
