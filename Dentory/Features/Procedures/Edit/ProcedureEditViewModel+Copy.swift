import Foundation

/// What Edit procedure says (f15, Appendix B `procEdit`): the title, the captions of the rows and of Add item, the
/// note under the list, the Delete sheet and the toasts. The state and the intents are in
/// `ProcedureEditViewModel.swift`.
extension ProcedureEditViewModel {
    static let multiUseCaption = "Multi-use · listed under Opened a new one?"
    static let note = "These are defaults. Staff can add or remove items for each procedure they perform."
    static let emptyText = "No supplies yet."
    static let nameTooLong = "Use 120 characters or fewer for the name."

    var title: String { isNew ? "New procedure" : "Edit procedure" }

    /// "Delete Root canal?"
    var deleteTitle: String { "Delete \(storedName)?" }

    var deleteMessage: String { "Past procedures keep their data." }

    /// "Anesthetic" under a product in Add item, "Anesthetic · multi-use" for a multi-use one.
    func addCaption(for product: ProductSummary) -> String? {
        guard product.tracking == .multiUse else { return product.categoryName }
        guard let category = product.categoryName else { return "Multi-use" }
        return "\(category) · multi-use"
    }

    /// Every product can join a template, so no row reads "Out of stock" here.
    var outOfStockProductID: UUID? { nil }

    func addCaptionTone(for product: ProductSummary) -> StatusTone? { nil }

    /// What Add item says with nothing to list: nothing while the products load, and how to retry when they failed.
    var addItemEmptyText: String {
        if hasLoadedProducts { return "No products match." }
        return productsFailed ? "Couldn't load products. Close and reopen Add item to try again." : ""
    }

    /// "Root canal · 12 default supplies" under "Procedure saved".
    static func savedDetail(_ saved: SavedProcedureTemplate) -> String {
        let supplies = saved.itemCount == 1 ? "1 default supply" : "\(saved.itemCount) default supplies"
        return "\(saved.name) · \(supplies)"
    }
}
