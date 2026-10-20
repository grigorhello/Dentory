import Foundation

/// The explainer's "offered" flag for the app, kept across launches.
final class UserDefaultsPushExplainerStore: PushExplainerStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "push.explainerOffered"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasOffered: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}
