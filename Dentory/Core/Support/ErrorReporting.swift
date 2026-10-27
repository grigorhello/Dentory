import Foundation

/// Crash and error reporting. Records which call failed and how, never what the user typed, nor names,
/// emails or invoice contents (MS-108).
protocol ErrorReporting: Sendable {
    func start()
    /// A failed RPC: the function name and the error's kind, as a breadcrumb for the next crash report.
    func record(_ error: AppError, function: String)
    /// Starts timing one call through `SupabaseRPCClient`, which finishes it once with how it ended (MS-150).
    func startCall(_ function: String) -> CallTiming
}

/// One timed call: Sentry gets a transaction named after the function, `ok` or failed with the error's kind, so
/// failures can be counted and durations charted per function. Nothing of the call's parameters or answer goes.
@MainActor
protocol CallTiming {
    /// nil when the call succeeded.
    func finish(with error: AppError?)
}

/// Reports nothing; for previews, tests and builds without a DSN.
struct NoopErrorReporter: ErrorReporting {
    func start() {}
    func record(_ error: AppError, function: String) {}
    func startCall(_ function: String) -> CallTiming { NoopCallTiming() }
}

/// Times nothing.
struct NoopCallTiming: CallTiming {
    func finish(with error: AppError?) {}
}

extension AppError {
    /// A short, data-free label for reports: `validation`, not the sentence the server sent.
    var reportingKind: String {
        switch self {
        case .network: "network"
        case .notFound: "not_found"
        case .forbidden: "forbidden"
        case .readOnly: "read_only"
        case .validation: "validation"
        case .unknown: "unknown"
        }
    }
}
