import Foundation
import Testing
@testable import Dentory

/// A line's amount on Review invoice (f23): the quantity in the unit it was read in, singular for one, and the price of
/// one in the invoice's currency.
@MainActor
struct InvoiceReviewAmountTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    /// The frames' invoice under review.
    private func make() -> InvoiceReviewViewModel {
        let repository = FakeInvoiceRepository()
        repository.lines = InvoiceLine.frames
        return InvoiceReviewViewModel(
            invoice: .ready(UUID(), with: InvoiceLine.frames), repository: repository, formatters: formatters,
            analytics: NoopAnalytics(), saveDelay: .milliseconds(10), reload: {}
        )
    }

    @Test func amountsReadInTheUnitAsReadAndThePriceOfOne() {
        let viewModel = make()
        let twoBoxes = InvoiceLine.line(9, "GLOVES", qty: 2, unit: "box", price: 12, .newProduct)
        let oneBox = InvoiceLine.line(9, "GLOVES", qty: 1, unit: "boxes", price: nil, .newProduct)
        let price = Decimal(string: "0.9960")
        let noQuantity = InvoiceLine.line(9, "GLOVES", qty: nil, unit: "box", price: price, .newProduct)
        #expect(viewModel.amount(for: twoBoxes) == "2 boxes\u{00A0}· $12.00")
        #expect(viewModel.amount(for: oneBox) == "1 box")
        #expect(viewModel.amount(for: noQuantity) == "$0.996", "A unit price keeps up to four decimals")
    }

    /// An invoice's EA is read as "each", which reads the same for any quantity.
    @Test func aLineReadInEachReadsEachForAnyQuantity() {
        let viewModel = make()
        let fourEach = InvoiceLine.line(9, "HEMOSTATIC GEL SYRINGE", qty: 4, unit: "each", price: 12, .newProduct)
        let oneEach = InvoiceLine.line(9, "RETRACTION CORD #1", qty: 1, unit: "each", price: 21, .newProduct)
        #expect(viewModel.amount(for: fourEach) == "4 each\u{00A0}· $12.00", "Not \"4 eaches\"")
        #expect(viewModel.amount(for: oneEach) == "1 each\u{00A0}· $21.00")
    }

    /// A unit read with its count ("pack of 10") takes the plural on the pack.
    @Test func aPackReadWithItsCountTakesThePluralOnThePack() {
        let viewModel = make()
        let threePacks = InvoiceLine.line(9, "MIXING TIPS", qty: 3, unit: "pack of 10", price: 8, .newProduct)
        let onePack = InvoiceLine.line(9, "MIXING TIPS", qty: 1, unit: "pack of 10", price: 8, .newProduct)
        #expect(viewModel.amount(for: threePacks) == "3 packs of 10\u{00A0}· $8.00")
        #expect(viewModel.amount(for: onePack) == "1 pack of 10\u{00A0}· $8.00")
    }
}
