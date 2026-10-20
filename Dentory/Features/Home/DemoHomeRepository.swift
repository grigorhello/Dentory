import Foundation

/// The figures of frame f6 for previews and UI tests.
struct DemoHomeRepository: HomeRepository {
    var summary = HomeSummary.demo
    /// When set, the bell's dot follows it: Activity's demo alerts clear it once seen (MS-133).
    var activity: DemoActivityRepository?

    func summary(clinicID: UUID) async throws -> HomeSummary {
        guard let activity else { return summary }
        return HomeSummary(
            toBuyCount: summary.toBuyCount,
            expiringBatchCount: summary.expiringBatchCount,
            missingExpiryProductCount: summary.missingExpiryProductCount,
            inventoryValue: summary.inventoryValue,
            valueAtRisk90: summary.valueAtRisk90,
            latestProcedure: summary.latestProcedure,
            hasUnseenAlerts: summary.hasUnseenAlerts && activity.hasUnseenAlerts
        )
    }
}

extension HomeSummary {
    nonisolated static let demo = HomeSummary(
        toBuyCount: 3,
        expiringBatchCount: 2,
        missingExpiryProductCount: 1,
        inventoryValue: 12_420,
        valueAtRisk90: 186,
        latestProcedure: LatestProcedure(
            id: UUID(uuidString: "00000000-0000-4000-8000-0000000000e1") ?? UUID(),
            name: "Root canal",
            startedAt: Date(timeIntervalSince1970: 1_790_882_040), // Oct 1 · 3:14 PM in New York
            supplyCount: 12,
            startedByFirstName: "Sarah"
        ),
        hasUnseenAlerts: true
    )

    /// A brand-new clinic: nothing to buy, no procedures yet.
    nonisolated static let empty = HomeSummary(
        toBuyCount: 0, expiringBatchCount: 0, missingExpiryProductCount: 0,
        inventoryValue: 0, valueAtRisk90: 0, latestProcedure: nil, hasUnseenAlerts: false
    )
}
