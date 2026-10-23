import Foundation

/// Expiry warning (f33, MS-100 D8): which thresholds raise an Expiring alert; a batch is Expiring within the largest.
nonisolated enum ExpiryWarning: CaseIterable, Hashable, Sendable {
    case thirtySixtyNinety
    case sixtyNinety
    case ninetyOnly

    init(thresholds: [Int]) {
        self = Self.allCases.first { $0.thresholds == thresholds.sorted() } ?? .thirtySixtyNinety
    }

    var thresholds: [Int] {
        switch self {
        case .thirtySixtyNinety: [30, 60, 90]
        case .sixtyNinety: [60, 90]
        case .ninetyOnly: [90]
        }
    }

    var label: String {
        switch self {
        case .thirtySixtyNinety: "30, 60 and 90 days"
        case .sixtyNinety: "60 and 90 days"
        case .ninetyOnly: "90 days only"
        }
    }
}
