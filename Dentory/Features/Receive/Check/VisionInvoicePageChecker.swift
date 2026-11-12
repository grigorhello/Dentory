import Foundation

/// The page check on the device, with Apple's frameworks and off the main actor (`InvoicePageCheck`): free, offline,
/// and done before anything is uploaded.
struct VisionInvoicePageChecker: InvoicePageChecker {
    func problem(inJPEG page: Data) async -> InvoicePageProblem? {
        await InvoicePageCheck.problem(inJPEG: page)
    }
}
