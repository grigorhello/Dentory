import Foundation

/// What the New / Edit product sheet says that is not a field (Appendix C `newProduct`): its title, the button, the
/// notice over an invoice line's product (MS-130), the category choices and the Multi-use caption. The fields, the
/// rules and the save are in `ProductFormViewModel.swift`.
extension ProductFormViewModel {
    var title: String { isEditing ? "Edit product" : "New product" }

    var submitTitle: String {
        switch mode {
        case .create: "Create product"
        case .createAndSelect: "Create and select"
        case .invoiceLine: "Create and use for this line"
        case .edit: "Save changes"
        }
    }

    /// From an invoice line: "From invoice: TEMPBOND NE 1PK. Name and unit are suggested. Check them and add the rest."
    var invoiceNotice: String? {
        guard case .invoiceLine(let raw, _, _) = mode else { return nil }
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return "From invoice: \(line). Name and unit are suggested. Check them and add the rest."
    }

    func categoryTitle(_ choice: CategoryChoice) -> String {
        switch choice {
        case .existing(let category): category.name
        case .new: "New category…"
        }
    }

    var trackingCaption: String { "Tracked as unopened and open items." }
}
