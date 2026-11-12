import Foundation

/// Why a captured page looks unreadable before it is read (MS-163): too dark, or text that cannot be made out (blurry,
/// out of focus, too far, or no invoice in the frame). The raw values are the `reason` the check's events carry.
nonisolated enum InvoicePageProblem: String, Hashable, Sendable {
    case blurry
    case dark
}
