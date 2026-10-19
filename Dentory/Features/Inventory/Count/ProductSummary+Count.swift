import Foundation

extension ProductSummary {
    /// The row with a counted unopened quantity; a multi-use product keeps its open bottles. The status is
    /// left to the server's next answer.
    nonisolated func counted(_ unopened: Decimal) -> ProductSummary {
        ProductSummary(
            id: id, name: name, categoryName: categoryName, unit: unit, tracking: tracking, location: location,
            quantity: unopened + (tracking == .multiUse ? Decimal(openCount) : 0), unopened: unopened,
            openCount: openCount, minimum: minimum, status: status
        )
    }
}
