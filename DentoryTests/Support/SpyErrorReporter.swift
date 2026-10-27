import Foundation
@testable import Dentory

/// Records the calls `SupabaseRPCClient` times (MS-150): which function, and how each ended, `ok` or the error's kind.
final class SpyErrorReporter: ErrorReporting, @unchecked Sendable {
    struct Call: Equatable {
        let function: String
        let outcome: String
    }

    private(set) var started: [String] = []
    private(set) var finished: [Call] = []

    func start() {}

    func record(_ error: AppError, function: String) {}

    func startCall(_ function: String) -> CallTiming {
        started.append(function)
        return Timing(function: function, reporter: self)
    }

    func ended(_ function: String, with error: AppError?) {
        finished.append(Call(function: function, outcome: error?.reportingKind ?? "ok"))
    }

    private struct Timing: CallTiming {
        let function: String
        let reporter: SpyErrorReporter

        func finish(with error: AppError?) {
            reporter.ended(function, with: error)
        }
    }
}
