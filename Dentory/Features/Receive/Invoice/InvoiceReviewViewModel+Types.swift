import Foundation

/// What Review invoice's lines open, wait for and say (MS-130): the sheet over them, the two choices a line waits for,
/// what a line's badge does, and the toasts. The state and the intents are in `InvoiceReviewViewModel.swift`.
extension InvoiceReviewViewModel {
    /// The sheet over the lines.
    enum Sheet: Identifiable, Equatable {
        /// Which product is this? (Appendix C `match`), from a New product's Pick existing, a fee's Pick product, or
        /// the badge of a line read as Matched or of a Possible match.
        case match(InvoiceLine)
        /// New product from the line (Appendix C `newProduct`), from Add new or No, create new.
        case newProduct(InvoiceLine)

        var id: String {
            switch self {
            case .match(let line): "match-\(line.id)"
            case .newProduct(let line): "newProduct-\(line.id)"
            }
        }
    }

    /// A choice a line waits for (Appendix B `invoice.line[n].a` and `.b`).
    enum Choice: Equatable {
        case yesMatch, createNew, addNew, pickExisting, ignore, pickProduct
    }

    /// What a line's badge does (Appendix B `invoice.line[n].state`).
    enum BadgeAction: Equatable {
        /// Back to the state, and the product, the line was read in (`invoice_line_reopen`).
        case reopen
        /// Which product is this?, to point the line at another product.
        case pickAnother
    }

    /// A toast the screen shows.
    struct Message: Equatable {
        let title: String
        let detail: String?
    }
}
