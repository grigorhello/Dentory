import Foundation
import Sentry

/// Sentry Cocoa, started with the DSN from Info.plist (`SENTRY_DSN`, set in `Config/Secrets*.xcconfig`).
/// With no DSN it stays off. Breadcrumbs carry the function name and the error kind only, and so does the
/// transaction each call through `SupabaseRPCClient` sends (MS-150, `docs/runbooks/monitoring.md`).
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
            // On by default whatever the line above says: a breadcrumb with every request's address, and an event
            // with the request for every 5xx answer (MS-151).
            options.enableNetworkBreadcrumbs = false
            options.enableCaptureFailedRequests = false
            // Sessions give the crash-free rate the first alert watches; on by default, kept on.
            options.enableAutoSessionTracking = true
            // Every call's transaction is kept, and they are the only ones: no screen, app start, tap or request is
            // traced on its own, and no Sentry header goes with the requests to Supabase.
            options.tracesSampleRate = 1.0
            options.enableAutoPerformanceTracing = false
            options.enableNetworkTracking = false
            options.tracePropagationTargets = []
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

    func startCall(_ function: String) -> CallTiming {
        guard dsn != nil else { return NoopCallTiming() }
        return SentryCallTiming(
            transaction: SentrySDK.startTransaction(name: function, operation: "rpc", bindToScope: false)
        )
    }
}

/// A call's transaction: `ok`, or a failed status, with the outcome as its `kind` tag (`ok` or the error's kind), so an
/// alert can leave out the refusals a clinic is meant to get and the calls of a device offline.
private struct SentryCallTiming: CallTiming {
    let transaction: Span

    func finish(with error: AppError?) {
        transaction.setTag(value: error?.reportingKind ?? "ok", key: "kind")
        guard let error else {
            transaction.finish(status: .ok)
            return
        }
        transaction.finish(status: Self.status(of: error))
    }

    /// Statuses Sentry counts as failures, so the failure rate of a function is its share of refused or lost calls.
    private static func status(of error: AppError) -> SentrySpanStatus {
        switch error {
        case .network: .unavailable
        case .notFound: .notFound
        case .forbidden: .permissionDenied
        case .readOnly: .failedPrecondition
        case .validation: .invalidArgument
        case .unknown: .internalError
        }
    }
}
