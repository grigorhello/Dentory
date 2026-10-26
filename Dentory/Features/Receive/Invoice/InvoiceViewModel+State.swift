import Foundation

/// Review invoice's states, from the upload to the review and on to the delivery received (MS-129 to MS-131), the
/// toast it hands back, and how it follows a reading. The intents are in `InvoiceViewModel.swift`.
extension InvoiceViewModel {
    enum State: Equatable {
        /// Opening an invoice: waiting for its first answer.
        case loading
        /// The invoice could not be opened.
        case loadFailed(AppError)
        /// The captured pages are going up.
        case uploading
        /// The pages could not be uploaded, or the invoice created.
        case uploadFailed(AppError)
        /// Being read on the server.
        case reading
        /// Read and waiting for review.
        case ready
        /// Received (MS-131): the lines as they came in, read-only.
        case received
        /// The reading failed.
        case failed
        /// Set aside since it was opened.
        case closed
    }

    /// How often the screen asks how the reading goes.
    static let pollInterval: Duration = .seconds(2)
    /// How many times a reading that has not started is asked for (a request lost on the way).
    static let maxReadingRequests = 3

    /// A toast the screen shows.
    struct Message: Equatable {
        let title: String
        let detail: String?
    }
}
