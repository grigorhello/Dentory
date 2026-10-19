import Foundation
import Observation

/// What Add item needs from the screen that opens it: Adjust, then start (MS-123) and Edit procedure (MS-125).
/// The screen owns the search, decides which products are offered and what each row says, and adds the one tapped.
@MainActor
protocol ProcedureItemPicking: AnyObject, Observable {
    var searchText: String { get set }
    /// The products not on the list yet that match the search, by name.
    var addableProducts: [ProductSummary] { get }
    /// What the list says when nothing matches; empty while the products load.
    var addItemEmptyText: String { get }
    func addCaption(for product: ProductSummary) -> String?
    func add(_ product: ProductSummary)
    /// Loads the clinic's products when the sheet opens.
    func loadProducts() async
}
