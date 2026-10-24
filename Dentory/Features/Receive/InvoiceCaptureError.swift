import Foundation

/// Why a capture gave no document.
nonisolated enum InvoiceCaptureError: Error, Equatable, Sendable {
    /// Over `InvoiceDocument.maxByteCount`.
    case tooLarge(InvoiceDocument.Source)
    /// The photos or the file could not be read.
    case unreadable(InvoiceDocument.Source)
    /// The document scanner stopped, for one because the camera is not allowed; it has said why itself.
    case scannerFailed
}
