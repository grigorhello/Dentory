import Foundation
import Sentry

/// Sentry Cocoa, started with the DSN from Info.plist (`SENTRY_DSN`, set in `Config/Secrets*.xcconfig`).
/// With no DSN it stays off. Breadcrumbs carry the function name and the error kind only.
struct SentryErrorReporter: ErrorReporting {
    let dsn: String?

    init(bundle: Bundle = .main) {
        let value = bundle.object(forInfoDictionaryKey: "SENTRY_DSN") as? String
        dsn = value.flatMap { $0.isEmpty || $0.hasPrefix("$(") ? nil : $0 }
    }

    func start() {
        guard let dsn else { return }
        SentrySDK.start { options in
            options.dsn = dsn
            options.sendDefaultPii = false
            options.attachScreenshot = false
            options.attachViewHierarchy = false
            options.enableAutoBreadcrumbTracking = false
            #if DEBUG
            options.environment = "debug"
            #endif
        }
    }

    func record(_ error: AppError, function: String) {
        guard dsn != nil else { return }
        let crumb = Breadcrumb(level: .error, category: "rpc")
        crumb.message = function
        crumb.data = ["kind": error.reportingKind]
        SentrySDK.addBreadcrumb(crumb)
    }
}
