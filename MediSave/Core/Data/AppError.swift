import Foundation

/// Every failure the app shows or branches on. Repositories throw these; view models turn them into copy.
nonisolated enum AppError: Error, Equatable, Sendable {
    case network
    case notFound
    case forbidden
    /// The clinic's trial ended without a payment method: reading works, writing does not (MS-100 G5).
    case readOnly
    /// A rule the server refused, with the sentence it gave ("A note is required to cancel").
    case validation(field: String?, message: String)
    case unknown(String)

    /// Copy from PRD §7: sentence case, no exclamation marks, states what to do next.
    var userMessage: String {
        switch self {
        case .network: "No connection. Your change will be retried."
        case .notFound: "This item no longer exists."
        case .forbidden: "You don't have permission to do this."
        case .readOnly: "Add a payment method to keep making changes."
        case .validation(_, let message): message
        case .unknown: "Couldn't save. Try again."
        }
    }
}
