import Foundation
import Testing
@testable import Dentory

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
        #expect(formatters.quantity(1, unit: "bottles") == "1 bottle", "One of a plural unit reads singular (f27)")
        #expect(formatters.quantity(1, unit: "boxes") == "1 box")
        #expect(formatters.quantity(1, unit: "pouches") == "1 pouch")
        #expect(formatters.quantity(0, unit: "kits") == "0 kits")
        #expect(formatters.quantity(1, unit: "ml") == "1 ml", "Not a plural: as it is")
        #expect(formatters.quantity(1, unit: "batteries") == "1 battery")
    }

    /// A field opens on a number it reads back whole, and reads what people type with or without separators.
    @Test func editableNumbersReadBackAsTyped() {
        #expect(formatters.editableNumber(1000) == "1000", "No thousands separator to stop the parse")
        #expect(formatters.editableNumber(2.5) == "2.5")
        #expect(formatters.parseNumber("1000") == 1000)
        #expect(formatters.parseNumber("1,000") == 1000)
        #expect(formatters.parseNumber(" 2.5 ") == 2.5)
        #expect(formatters.parseNumber("-1") == -1)
        #expect(formatters.parseNumber("abc") == nil)
        #expect(formatters.parseNumber("") == nil)
        let french = ClinicFormatters(
            currency: "CAD", timeZone: formatters.timeZone, locale: Locale(identifier: "fr_CA"), clock: formatters.clock
        )
        #expect(french.parseNumber(french.editableNumber(1234.5)) == 1234.5, "Round trip with a decimal comma")
    }

    @Test func datesInTheClinicTimeZone() {
        let december1 = Date(timeIntervalSince1970: 1_796_101_200) // 2026-12-01 05:00 UTC, midnight in New York
        #expect(formatters.date(december1) == "Dec 1, 2026")
        // The frames say Thursday; October 2, 2026 is a Friday.
        #expect(formatters.weekday(Session.demoNow) == "Friday, October 2")
        #expect(formatters.time(Date(timeIntervalSince1970: 1_790_944_800)) == "8:40\u{202F}AM", "In New York")
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
