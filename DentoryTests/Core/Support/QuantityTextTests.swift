import Foundation
import Testing
@testable import Dentory

struct QuantityTextTests {
    private let english = Locale(identifier: "en_US")
    private let french = Locale(identifier: "fr_CA")

    @Test func quantitiesParseAsTypedInTheClinicsLocale() {
        #expect(QuantityText.parse(" 20 ", locale: english) == 20)
        #expect(QuantityText.parse("1,000.5", locale: english) == Decimal(string: "1000.5"))
        #expect(QuantityText.parse("1 000,5", locale: french) == Decimal(string: "1000.5"))
        #expect(QuantityText.parse("2,5", locale: french) == Decimal(string: "2.5"))
        #expect(QuantityText.parse("20.5", locale: french) == Decimal(string: "20.5"))
        #expect(QuantityText.parse("١٠", locale: english) == 10)
        #expect(QuantityText.parse(".5", locale: english) == Decimal(string: "0.5"))
        #expect(QuantityText.parse("5.", locale: english) == 5)
    }

    @Test func anythingElseIsNotAQuantity() {
        #expect(QuantityText.parse("", locale: english) == nil)
        #expect(QuantityText.parse(".", locale: english) == nil)
        #expect(QuantityText.parse("ten", locale: english) == nil)
        #expect(QuantityText.parse("12abc", locale: english) == nil)
        #expect(QuantityText.parse("-3", locale: english) == nil, "Typed quantities are never negative")
        #expect(QuantityText.parse("1.2.3", locale: english) == nil)
    }

    @Test func plainTextHasNoGroupingAndReadsBack() {
        #expect(QuantityText.plain(1000, locale: english) == "1000")
        #expect(QuantityText.plain(Decimal(string: "20.5") ?? 0, locale: french) == "20,5")
        for id in ["en_US", "fr_CA", "ar_SA", "de_DE"] {
            let locale = Locale(identifier: id)
            #expect(QuantityText.parse(QuantityText.plain(2500, locale: locale), locale: locale) == 2500, "\(id)")
        }
    }

    @Test func countsAreWholeNumbersOfOneOrMore() {
        #expect(QuantityText.count("50", locale: english) == 50)
        #expect(QuantityText.count("٥٠", locale: english) == 50)
        #expect(QuantityText.count("2.5", locale: english) == nil)
        #expect(QuantityText.count("0", locale: english) == nil)
        #expect(QuantityText.count("box", locale: english) == nil)
    }
}
