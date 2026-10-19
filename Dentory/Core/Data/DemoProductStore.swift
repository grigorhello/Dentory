import Foundation

/// The demo clinic's products and categories, shared by the demo repositories so a product created,
/// edited or deleted on one screen shows on the others within the same launch (previews, UI tests).
final class DemoProductStore: @unchecked Sendable {
    private let lock = NSLock()
    private var summaries: [ProductSummary] = ProductSummary.demo
    private var drafts: [UUID: ProductDraft] = [:]
    private var categoryList: [ProductCategory] = ProductCategory.demo

    var categories: [ProductCategory] { lock.withLock { categoryList } }
    var products: [ProductSummary] { lock.withLock { summaries } }

    func summary(id: UUID) -> ProductSummary? {
        lock.withLock { summaries.first { $0.id == id } }
    }

    /// The last draft saved for the product, if the sheet changed it.
    func draft(for id: UUID) -> ProductDraft? {
        lock.withLock { drafts[id] }
    }

    func categoryName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return lock.withLock { categoryList.first { $0.id == id }?.name }
    }

    func findOrCreateCategory(named name: String) -> ProductCategory {
        lock.withLock {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing = categoryList.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                return existing
            }
            let created = ProductCategory(id: UUID(), name: trimmed)
            categoryList.append(created)
            return created
        }
    }

    /// A new product holds no stock yet, so it is Out of stock until a delivery.
    func create(_ draft: ProductDraft) -> UUID {
        let id = UUID()
        lock.withLock {
            summaries.append(
                Self.summary(id: id, draft: draft, quantity: 0, unopened: 0, openCount: 0, categories: categoryList)
            )
            drafts[id] = draft
        }
        return id
    }

    /// False when the product is unknown (or archived).
    func update(id: UUID, draft: ProductDraft) -> Bool {
        lock.withLock {
            guard let index = summaries.firstIndex(where: { $0.id == id }) else { return false }
            let current = summaries[index]
            summaries[index] = Self.summary(
                id: id, draft: draft, quantity: current.quantity, unopened: current.unopened,
                openCount: current.openCount, categories: categoryList,
                keeping: draft.minimum == current.minimum && draft.tracking == current.tracking ? current.status : nil
            )
            drafts[id] = draft
            return true
        }
    }

    /// False when the product is unknown (or already archived).
    func archive(id: UUID) -> Bool {
        lock.withLock {
            guard summaries.contains(where: { $0.id == id }) else { return false }
            summaries.removeAll { $0.id == id }
            return true
        }
    }

    // swiftlint:disable:next function_parameter_count
    private static func summary(
        id: UUID, draft: ProductDraft, quantity: Decimal, unopened: Decimal, openCount: Int,
        categories: [ProductCategory], keeping status: ProductStatus? = nil
    ) -> ProductSummary {
        ProductSummary(
            id: id,
            name: draft.name,
            categoryName: categories.first { $0.id == draft.categoryID }?.name,
            unit: draft.unit,
            tracking: draft.tracking,
            location: draft.location,
            quantity: quantity,
            unopened: unopened,
            openCount: openCount,
            minimum: draft.minimum,
            status: status ?? ProductStatus.evaluate(ProductStatus.Figures(
                tracking: draft.tracking, quantity: quantity, unopened: unopened, minimum: draft.minimum,
                missingExpiryQuantity: 0, daysToSoonestExpiry: nil, largestThreshold: 90
            ))
        )
    }
}
