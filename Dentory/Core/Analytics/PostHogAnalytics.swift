import Foundation
import PostHog

/// PostHog (MS-147), started with the project token from Info.plist (`POSTHOG_PROJECT_TOKEN`, set in
/// `Config/Secrets*.xcconfig`) on the EU cloud unless `POSTHOG_HOST` names another. With no token it stays off, as in
/// Debug builds without `Secrets.debug.xcconfig`. Only the events the app sends go out, with PostHog's app lifecycle
/// events (opened, backgrounded, installed, updated) for the active clinics: no autocapture, no screen views, no
/// session replay, no surveys, no push token, no location from the IP address.
struct PostHogAnalytics: Analytics {
    static let euHost = "https://eu.i.posthog.com"

    let token: String?
    let host: String

    init(bundle: Bundle = .main) {
        token = Self.setting("POSTHOG_PROJECT_TOKEN", in: bundle)
        host = Self.setting("POSTHOG_HOST", in: bundle) ?? Self.euHost
    }

    /// A build setting expanded into Info.plist; empty or unexpanded means unset.
    private static func setting(_ key: String, in bundle: Bundle) -> String? {
        let value = (bundle.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespaces)
        return value.flatMap { $0.isEmpty || $0.hasPrefix("$(") ? nil : $0 }
    }

    func start() {
        guard let token else { return }
        let config = PostHogConfig(projectToken: token, host: host)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.captureAutocaptureElementText = false
        config.rageClickConfig.enabled = false
        config.sessionReplay = false
        config.surveys = false
        config.capturePushNotificationSubscriptions = false
        config.capturePushNotificationOpened = false
        config.enableSwizzling = false
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false
        config.setDefaultPersonProperties = false
        config.disableGeoIp = true
        config.personProfiles = .identifiedOnly
        PostHogSDK.shared.setup(config)
    }

    func identify(_ session: Session) {
        guard token != nil else { return }
        let userID = session.userID.uuidString.lowercased()
        let clinicID = session.clinicID.uuidString.lowercased()
        let role = AnalyticsWord(session.role).rawValue
        // PostHog keeps the first member a device was identified as: another member's session (a link that replaced
        // it, even before a relaunch) starts over first, or their events would count as the earlier member's.
        let current = PostHogSDK.shared.getDistinctId()
        if current != userID, current != PostHogSDK.shared.getAnonymousId() {
            PostHogSDK.shared.reset()
        }
        PostHogSDK.shared.identify(userID, userProperties: ["role": role])
        PostHogSDK.shared.register(["role": role, "clinic_id": clinicID])
        PostHogSDK.shared.group(type: "clinic", key: clinicID)
    }

    func track(_ event: AnalyticsEvent) {
        guard token != nil else { return }
        PostHogSDK.shared.capture(event.name.rawValue, properties: event.payload.mapValues(\.any))
    }

    func reset() {
        guard token != nil else { return }
        PostHogSDK.shared.reset()
    }
}
