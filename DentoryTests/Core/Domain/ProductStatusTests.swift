import Foundation
import Testing
@testable import Dentory

/// The same 14 cases as `supabase/tests/database/07_product_status_test.sql`; change both together.
nonisolated struct ProductStatusTests {
    struct Case: Sendable {
        let name: String
        let figures: ProductStatus.Figures
        let expected: ProductStatus
    }

    private static func make(
        _ name: String, _ tracking: TrackingMode = .countable, quantity: Decimal, unopened: Decimal? = nil,
        minimum: Decimal, missing: Decimal = 0, days: Int? = nil, threshold: Int = 90, expected: ProductStatus
    ) -> Case {
        Case(
            name: name,
            figures: ProductStatus.Figures(
                tracking: tracking, quantity: quantity, unopened: unopened ?? quantity, minimum: minimum,
                missingExpiryQuantity: missing, daysToSoonestExpiry: days, largestThreshold: threshold
            ),
            expected: expected
        )
    }

    static let table: [Case] = [
        make("countable, plenty, dated far away", quantity: 54, minimum: 20, days: 200, expected: .healthy),
        make("countable at zero", quantity: 0, minimum: 3, expected: .outOfStock),
        make("countable negative (shortfall)", quantity: -2, minimum: 3, expected: .outOfStock),
        make("countable at the minimum", quantity: 20, minimum: 20, days: 200, expected: .low),
        make("countable low beats expiring", quantity: 2, minimum: 3, days: 10, expected: .low),
        make("countable expiring inside the window", quantity: 54, minimum: 20, days: 60, expected: .expiring),
        make("countable expiring on the last day of the window", quantity: 54, minimum: 20, days: 90,
             expected: .expiring),
        make("countable just outside the window", quantity: 54, minimum: 20, days: 91, expected: .healthy),
        make("countable with an expired batch", quantity: 54, minimum: 20, days: -5, expected: .expiring),
        make("countable expiring beats missing expiry", quantity: 54, minimum: 20, missing: 3, days: 60,
             expected: .expiring),
        make("countable with undated stock only", quantity: 54, minimum: 20, missing: 54, expected: .missingExpiry),
        make("multi-use with one open and none unopened", .multiUse, quantity: 1, unopened: 0, minimum: 1,
             expected: .low),
        make("multi-use with nothing open or unopened", .multiUse, quantity: 0, unopened: 0, minimum: 1,
             expected: .outOfStock),
        make("narrow threshold set keeps a 60-day batch healthy", quantity: 54, minimum: 20, days: 60, threshold: 30,
             expected: .healthy)
    ]

    @Test(arguments: table) func evaluatesLikeTheDatabase(_ testCase: Case) {
        #expect(ProductStatus.evaluate(testCase.figures) == testCase.expected, Comment(rawValue: testCase.name))
    }

    @Test func titlesAreThePRDStatusWords() {
        #expect(ProductStatus.allCases.map(\.title) == ["Out of stock", "Low", "Expiring", "Missing expiry", "Healthy"])
    }
}
