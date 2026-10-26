import Foundation
import Observation

/// Which product is this? (Appendix C `match`), over Review invoice for a New product's Pick existing, a fee's Pick
/// product, or the badge of a line read as Matched or of a Possible match: the line as read, a search, and the clinic's
/// products, each with its category and stock ("Anesthetic · 54 cartridges"). A tap picks the product, and the line is
/// Matched to it (`InvoiceReviewViewModel.choose`).
@MainActor
@Observable
final class InvoiceMatchViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    let line: InvoiceLine
    private(set) var state: LoadState = .loading
    /// The clinic's active products, by name.
    private(set) var products: [ReceivableProduct] = []
    var searchText = ""

    private let repository: ReceivableProductsRepository
    private let formatters: ClinicFormatters
    private let clinicID: UUID

    init(line: InvoiceLine, repository: ReceivableProductsRepository, formatters: ClinicFormatters, clinicID: UUID) {
        self.line = line
        self.repository = repository
        self.formatters = formatters
        self.clinicID = clinicID
    }

    static let title = "Which product is this?"

    func load() async {
        do {
            products = try await repository.products(clinicID: clinicID)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            state = .loaded
        } catch {
            state = .failed(AppError(error))
        }
    }

    /// The products matching the search, case and accent insensitive.
    var pickableProducts: [ReceivableProduct] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return products }
        return products.filter { $0.name.localizedStandardContains(query) }
    }

    /// What the list says when it has no row: nothing matches, the clinic has no product yet, or they did not load
    /// (nothing while they load).
    var emptyText: String {
        switch state {
        case .loaded: products.isEmpty ? "No products yet." : "No products match."
        case .failed: "Couldn't load products. Close and reopen this sheet to try again."
        case .loading: ""
        }
    }

    /// "Anesthetic · 54 cartridges", or a multi-use product's unopened and open ones, "Restorative · 1 unopened · 1
    /// open".
    func caption(for product: ReceivableProduct) -> String {
        let stock = switch product.tracking {
        case .countable: formatters.quantity(product.quantity, unit: product.unit)
        case .multiUse: "\(formatters.number(product.unopened)) unopened · \(product.openCount) open"
        }
        guard let category = product.categoryName, !category.isEmpty else { return stock }
        return "\(category) · \(stock)"
    }
}
