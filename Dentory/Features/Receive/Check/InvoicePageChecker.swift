import Foundation

/// Looks at one captured JPEG page on the device before the invoice is uploaded and read (MS-163). Tests use a fake;
/// the app uses `VisionInvoicePageChecker`.
protocol InvoicePageChecker: Sendable {
    /// What makes the page clearly unreadable, or nil when it may go on. A check that cannot run passes the page.
    func problem(inJPEG page: Data) async -> InvoicePageProblem?
}
