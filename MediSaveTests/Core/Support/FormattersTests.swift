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
        // The frames say Thursday; October 2, 2026 is a Friday.
        #expect(formatters.weekday(Session.demoNow) == "Friday, October 2")
        #expect(formatters.date(CalendarDay(year: 2026, month: 12, day: 1)) == "Dec 1, 2026")
        #expect(formatters.month(CalendarDay(year: 2026, month: 12, day: 1)) == "December 2026")
    }

    @Test func daysLeftCopy() {
        #expect(formatters.daysLeft(12) == "in 12 days")
        #expect(formatters.daysLeft(1) == "in 1 day")
        #expect(formatters.daysLeft(0) == "today")
        #expect(formatters.daysLeft(-3) == "Expired")
    }

    @Test func daysToExpiryCountsToTheLastDayOfTheMonth() {
        // demoNow is Thursday, October 2, 2026 in New York; December 2026 ends on the 31st: 90 days.
        #expect(formatters.daysToExpiry(month: CalendarDay(year: 2026, month: 12, day: 1)) == 90)
        #expect(formatters.daysToExpiry(month: CalendarDay(year: 2026, month: 10, day: 1)) == 29)
        #expect(formatters.daysToExpiry(month: CalendarDay(year: 2026, month: 9, day: 1)) == -2)
    }

    @Test func aDecodedDateColumnIsADayNotAnInstant() throws {
        struct Row: Decodable { let expiryMonth: CalendarDay }
        let row = try JSONDecoder.supabase.decode(Row.self, from: Data(#"{"expiry_month":"2026-12-01"}"#.utf8))
        #expect(formatters.daysToExpiry(month: row.expiryMonth) == 90)
        #expect(formatters.month(row.expiryMonth) == "December 2026")
        #expect(formatters.date(row.expiryMonth) == "Dec 1, 2026")
        let encoded = try JSONEncoder.supabase.encode(row.expiryMonth)
        #expect(String(bytes: encoded, encoding: .utf8) == "\"2026-12-01\"")
    }
}
