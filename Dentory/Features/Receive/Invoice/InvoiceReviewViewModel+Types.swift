import Foundation

/// What Review invoice's lines open, wait for and say (MS-130): the sheet over them, the two choices a line waits for,
/// and the toasts. The state and the intents are in `InvoiceReviewViewModel.swift`.
extension InvoiceReviewViewModel {
    /// The sheet over the lines.
    enum Sheet: Identifiable, Equatable {
        /// Which product is this? (Appendix C `match`), from a New product's Pick existing or a fee's Pick product.
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

    /// A toast the screen shows.
    struct Message: Equatable {
        let title: String
        let detail: String?
    }
}
