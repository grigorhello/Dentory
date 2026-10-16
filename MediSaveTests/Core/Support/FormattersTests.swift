import Foundation
import Testing
@testable import MediSave

struct FormattersTests {
    private let formatters = ClinicFormatters(
        currency: "USD",
        timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"),
        clock: FixedClock(Session.demoNow)
    )

    @Test func moneyInTheClinicCurrency() {
        #expect(formatters.money(1234.5) == "$1,234.50")
        #expect(formatters.money(186) == "$186.00")
    }

    @Test func quantitiesWithTheirUnit() {
        #expect(formatters.quantity(54, unit: "cartridges") == "54 cartridges")
        #expect(formatters.quantity(2.5, unit: "bags") == "2.5 bags")
    }

    @Test func datesInTheClinicTimeZone() {
        let december1 = Date(timeIntervalSince1970: 1_796_101_200) // 2026-12-01 05:00 UTC, midnight in New York
        #expect(formatters.date(december1) == "Dec 1, 2026")
        #expect(formatters.month(december1) == "December 2026")
    }

    @Test func daysLeftCopy() {
        #expect(formatters.daysLeft(12) == "in 12 days")
        #expect(formatters.daysLeft(1) == "in 1 day")
        #expect(formatters.daysLeft(0) == "today")
        #expect(formatters.daysLeft(-3) == "Expired")
    }

    @Test func daysToExpiryCountsToTheLastDayOfTheMonth() {
        // demoNow is Thursday, October 2, 2026 in New York; December 2026 ends on the 31st: 90 days.
        let december = Date(timeIntervalSince1970: 1_796_101_200)
        #expect(formatters.daysToExpiry(month: december) == 90)
    }
}
