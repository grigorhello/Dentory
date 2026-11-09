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

    @Test func unitCostsKeepTheirCents() {
        #expect(formatters.unitCost(Decimal(180) / 100) == "$1.80")
        #expect(formatters.unitCost(42) == "$42.00")
        #expect(formatters.unitCost(Decimal(425) / 10_000) == "$0.0425", "A last unit cost keeps up to four decimals")
        #expect(formatters.wholeMoney(Decimal(9_720) / 100) == "$97")
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

    /// The pack units a clinic types, in the plural (New product's sentence, Receive manually's quantity).
    @Test func pluralsOfTheUnitsAClinicTypes() {
        #expect(ClinicFormatters.plural(of: "box") == "boxes")
        #expect(ClinicFormatters.plural(of: "bottle") == "bottles")
        #expect(ClinicFormatters.plural(of: "packs") == "packs")
        #expect(ClinicFormatters.plural(of: "pouch") == "pouches")
        #expect(ClinicFormatters.plural(of: "case") == "cases")
        #expect(ClinicFormatters.plural(of: "battery") == "batteries")
        #expect(ClinicFormatters.plural(of: "tray") == "trays")
    }

    /// The units an invoice is read in (Review invoice): "each" is an invoice's EA, never "eaches".
    @Test func unitsTheSameInBothAndAbbreviationsStayAsTheyAre() {
        #expect(ClinicFormatters.plural(of: "each") == "each")
        #expect(ClinicFormatters.plural(of: "Each") == "Each")
        #expect(ClinicFormatters.plural(of: "ea") == "ea")
        #expect(ClinicFormatters.plural(of: "EA") == "EA")
        #expect(ClinicFormatters.plural(of: "dozen") == "dozen")
        #expect(ClinicFormatters.plural(of: "oz") == "oz")
        #expect(ClinicFormatters.plural(of: "pk") == "pk", "No vowel: an abbreviation")
        #expect(ClinicFormatters.plural(of: "ml") == "ml")
        #expect(ClinicFormatters.plural(of: "10/pk") == "10/pk")
        #expect(ClinicFormatters.plural(of: "") == "")
        #expect(ClinicFormatters.singular(of: "each") == "each")
        #expect(formatters.quantity(4, unit: "each") == "4 each")
    }

    /// A unit with a count after it: the word before the count takes the plural.
    @Test func aPackWithItsCountTakesThePluralOnThePack() {
        #expect(ClinicFormatters.plural(of: "pack of 10") == "packs of 10")
        #expect(ClinicFormatters.plural(of: "box of 100") == "boxes of 100")
        #expect(ClinicFormatters.plural(of: "box (100)") == "boxes (100)")
        #expect(ClinicFormatters.plural(of: "box/100") == "boxes/100")
        #expect(ClinicFormatters.plural(of: "4oz bottle") == "4oz bottles", "A number inside the first word stays")
        #expect(ClinicFormatters.singular(of: "packs of 10") == "pack of 10")
        #expect(ClinicFormatters.singular(of: "boxes (100)") == "box (100)")
        #expect(formatters.quantity(1, unit: "packs of 10") == "1 pack of 10")
    }

    /// Receive manually shows one pack as the singular of the pack unit's plural ("1 box = 50 cartridges").
    @Test func theSingularOfAPluralIsTheUnitAgain() {
        let units = [
            "box", "bottle", "pouch", "case", "battery", "tray", "brush", "syringe", "cartridge", "piece", "kit",
            "sterile pouch", "each", "ea", "dozen", "pk", "ml", "pack of 10", "box (100)", "4oz bottle"
        ]
        for unit in units {
            #expect(ClinicFormatters.singular(of: ClinicFormatters.plural(of: unit)) == unit, "\(unit)")
        }
    }

    /// What a money field shows before the amount (Receive manually's cost).
    @Test func theCurrencySymbolFollowsTheClinicsCurrencyAndTheLocale() {
        #expect(formatters.currencySymbol == "$")
        let canada = Locale(identifier: "en_CA")
        let zone = formatters.timeZone
        let cad = ClinicFormatters(currency: "CAD", timeZone: zone, locale: canada, clock: formatters.clock)
        #expect(cad.currencySymbol == "$")
        let usd = ClinicFormatters(currency: "USD", timeZone: zone, locale: canada, clock: formatters.clock)
        #expect(usd.currencySymbol == "US$")
    }

    /// Where the expiry wheels open and which years they offer (Add expiry, Receive manually).
    @Test func theExpiryWheelsOpenOnThisMonthInTheClinicsTimeZone() {
        #expect(formatters.thisMonth == CalendarDay(year: 2026, month: 10, day: 1))
        #expect(formatters.expiryYears(including: nil) == 2023...2036)
        #expect(formatters.expiryYears(including: CalendarDay(year: 2040, month: 6, day: 1)) == 2023...2040)
        #expect(formatters.expiryYears(including: CalendarDay(year: 2019, month: 6, day: 1)) == 2019...2036)
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
