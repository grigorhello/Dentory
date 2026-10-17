import Foundation
import Observation

/// Runs one submission at a time: a second tap while the first is in flight is ignored, so a double tap
/// on Start procedure creates one event (MS-108). View models own one per primary action and bind
/// `isBusy` to the button's `isLoading`.
@MainActor
@Observable
final class SubmitGuard {
    private(set) var isBusy = false

    /// Runs `operation` unless one is already running; returns false when the tap was ignored.
    @discardableResult
    func run(_ operation: () async -> Void) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        await operation()
        return true
    }
}
