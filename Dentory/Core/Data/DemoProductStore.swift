import Foundation

/// The demo clinic's products and categories, shared by the demo repositories so a product created,
/// edited, counted or deleted on one screen shows on the others within the same launch (previews, UI tests).
final class DemoProductStore: @unchecked Sendable {
    /// A count that moved one product, for the demo detail's figures, "Counted" line and history.
    struct CountRecord: Equatable, Sendable {
        let quantityBefore: Decimal
        let quantityAfter: Decimal
        let at: Date
        let byName: String

        var delta: Decimal { quantityAfter - quantityBefore }
    }

    private let lock = NSLock()
    private var summaries: [ProductSummary] = ProductSummary.demo
    private var drafts: [UUID: ProductDraft] = [:]
    private var categoryList: [ProductCategory] = ProductCategory.demo
    private var countRecords: [UUID: [CountRecord]] = [:]

    var categories: [ProductCategory] { lock.withLock { categoryList } }
    var products: [ProductSummary] { lock.withLock { summaries } }

    func summary(id: UUID) -> ProductSummary? {
        lock.withLock { summaries.first { $0.id == id } }
    }

    /// The last draft saved for the product, if the sheet changed it.
    func draft(for id: UUID) -> ProductDraft? {
        lock.withLock { drafts[id] }
    }

    /// The pack a product is received in (MS-127, MS-131): the one its New product or Edit sheet gave it in this
    /// launch, or the seed's (Septocaine in boxes of 50, Nitrile gloves in cases of 10, Suction tips in cases of 4).
    func pack(of id: UUID) -> (unit: String, size: Int)? {
        if let draft = draft(for: id) {
            return draft.packUnit.flatMap { unit in draft.packSize.map { (unit: unit, size: $0) } }
        }
        return Self.seedPacks[id]
    }

    private static let seedPacks: [UUID: (unit: String, size: Int)] = [
        ProductSummary.demo[0].id: ("box", 50),
        ProductSummary.demo[4].id: ("case", 10),
        ProductSummary.demo[10].id: ("case", 4)
    ]

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

    /// A status the demo works out elsewhere, such as Missing expiry cleared by Add expiry (MS-119).
    func setStatus(_ status: ProductStatus, for id: UUID) {
        lock.withLock {
            guard let index = summaries.firstIndex(where: { $0.id == id }) else { return }
            let current = summaries[index]
            summaries[index] = ProductSummary(
                id: current.id, name: current.name, categoryName: current.categoryName, unit: current.unit,
                tracking: current.tracking, location: current.location, quantity: current.quantity,
                unopened: current.unopened, openCount: current.openCount, minimum: current.minimum, status: status
            )
        }
    }

    /// Applies counted unopened quantities the way `stock_count_apply` does: a line that matches the stock
    /// changes nothing; any other moves the product's figures and status (an increase lands on the undated
    /// quantity, MS-100 D9) and is recorded, newest first. Returns how many products changed.
    @discardableResult
    func applyCount(_ counts: [CountedQuantity], at date: Date, by byName: String) -> Int {
        lock.withLock {
            var changed = 0
            for line in counts {
                guard let index = summaries.firstIndex(where: { $0.id == line.productID }) else { continue }
                let current = summaries[index]
                guard line.counted != current.unopened else { continue }
                let updated = current.afterCount(line.counted)
                summaries[index] = updated
                let record = CountRecord(
                    quantityBefore: current.quantity, quantityAfter: updated.quantity, at: date, byName: byName
                )
                countRecords[line.productID, default: []].insert(record, at: 0)
                changed += 1
            }
            return changed
        }
    }

    /// The counts applied to the product in this launch, newest first.
    func countRecords(for id: UUID) -> [CountRecord] {
        lock.withLock { countRecords[id] ?? [] }
    }

    /// A delivery received by hand (MS-127), in counted units: it joins the unopened stock, undated unless it came
    /// with an expiry, and the status follows as `stock_receive` leaves it. False when the product is unknown (or
    /// archived).
    func receive(_ quantity: Decimal, of id: UUID, dated: Bool) -> Bool {
        lock.withLock {
            guard let index = summaries.firstIndex(where: { $0.id == id }) else { return false }
            summaries[index] = summaries[index].afterReceiving(quantity, dated: dated)
            return true
        }
    }

    /// Undo of an invoice's delivery (MS-131): the products it received are as they were before it.
    func restore(_ before: [ProductSummary]) {
        lock.withLock {
            summaries = summaries.map { current in before.first { $0.id == current.id } ?? current }
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

private extension ProductSummary {
    /// The row after a count of its unopened stock, with the status the server would give: a decrease takes
    /// from the dated batches first and an increase lands on the undated quantity, so an increase reads
    /// Missing expiry unless the product is low or expiring (MS-100 D9).
    nonisolated func afterCount(_ unopened: Decimal) -> ProductSummary {
        let row = counted(unopened)
        let increase = max(unopened - self.unopened, 0)
        let undated = status == .missingExpiry ? max(unopened, increase) : increase
        let status = ProductStatus.evaluate(ProductStatus.Figures(
            tracking: tracking, quantity: row.quantity, unopened: unopened, minimum: minimum,
            missingExpiryQuantity: undated, daysToSoonestExpiry: status == .expiring ? 0 : nil, largestThreshold: 90
        ))
        return ProductSummary(
            id: id, name: name, categoryName: categoryName, unit: unit, tracking: tracking, location: location,
            quantity: row.quantity, unopened: unopened, openCount: openCount, minimum: minimum, status: status
        )
    }

    /// The row after a delivery: the quantity joins the unopened stock, undated (Missing expiry) unless it came with
    /// an expiry; an expiring product keeps its expiring batch.
    nonisolated func afterReceiving(_ received: Decimal, dated: Bool) -> ProductSummary {
        let newUnopened = unopened + received
        let newQuantity = quantity + received
        let undated = (status == .missingExpiry ? max(unopened, 0) : 0) + (dated ? 0 : received)
        let newStatus = ProductStatus.evaluate(ProductStatus.Figures(
            tracking: tracking, quantity: newQuantity, unopened: newUnopened, minimum: minimum,
            missingExpiryQuantity: undated, daysToSoonestExpiry: status == .expiring ? 0 : nil, largestThreshold: 90
        ))
        return ProductSummary(
            id: id, name: name, categoryName: categoryName, unit: unit, tracking: tracking, location: location,
            quantity: newQuantity, unopened: newUnopened, openCount: openCount, minimum: minimum, status: newStatus
        )
    }
}
