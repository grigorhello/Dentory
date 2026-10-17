import Testing
@testable import Dentory

struct StatusBadgeKindTests {
    @Test func productStatusesUseTheTicketTones() {
        #expect(StatusBadgeKind.healthy.tone == .success)
        #expect(StatusBadgeKind.low.tone == .warning)
        #expect(StatusBadgeKind.outOfStock.tone == .danger)
        #expect(StatusBadgeKind.expiring.tone == .warning)
        #expect(StatusBadgeKind.missingExpiry.tone == .info)
    }

    @Test func labelsAreThePRDStatusWords() {
        let words = StatusBadgeKind.allCases.map(\.rawValue)
        #expect(words == [
            "Healthy", "Low", "Out of stock", "Expiring", "Missing expiry",
            "Matched", "Possible match", "New product", "Needs review", "Created", "Skipped"
        ])
    }
}
