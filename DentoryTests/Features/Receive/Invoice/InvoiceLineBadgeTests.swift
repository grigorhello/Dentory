import Foundation
import Testing
@testable import Dentory

/// A line's badge on Review invoice (the decision on #101): a line read as Matched, and a Possible match, open Which
/// product is this? and take the product picked; the badge of a line so changed reopens it to the product it was read
/// as, or to the suggestion; a New product's and a fee's badge do nothing; Which product is this? waits while the
/// line's choice is saved; and what VoiceOver says the badge does.
@MainActor
struct InvoiceLineBadgeTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    /// The frames' invoice under review.
    private func make(_ repository: FakeInvoiceRepository) -> InvoiceReviewViewModel {
        repository.lines = InvoiceLine.frames
        return InvoiceReviewViewModel(
            invoice: .ready(UUID(), with: InvoiceLine.frames), repository: repository, formatters: formatters,
            analytics: NoopAnalytics(), saveDelay: .milliseconds(10), reload: {}
        )
    }

    private func line(_ number: Int, in viewModel: InvoiceReviewViewModel) throws -> InvoiceLine {
        try #require(viewModel.lines.first { $0.number == number })
    }

    /// A line read as Matched: its badge opens Which product is this?, the product picked replaces the one read, and
    /// the badge then reopens the line to the product it was read as.
    @Test func aLineMatchedWhenReadIsChangedFromItsBadgeAndReopensToTheProductRead() async throws {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        #expect(viewModel.badgeAction(for: InvoiceLine.septo) == .pickAnother)
        await viewModel.tapBadge(on: InvoiceLine.septo)
        #expect(viewModel.sheet == .match(InvoiceLine.septo))
        #expect(repository.calls.isEmpty, "Nothing is saved before a product is picked")

        await viewModel.choose(ReceivableProduct.composite.id, for: InvoiceLine.septo)
        let changed = try line(1, in: viewModel)
        #expect(viewModel.sheet == nil)
        #expect(repository.calls == [.match(InvoiceLine.septo.id, product: ReceivableProduct.composite.id)])
        #expect(changed.state == .matched && viewModel.headline(for: changed) == "Composite A2")
        #expect(changed.readState == .matched, "The state it was read in stays (MS-147)")
        #expect(changed.readProductID == ReceivableProduct.septocaine.id, "and the product it was read as")
        #expect(changed.isMatchChanged && changed.canReopen)
        #expect(viewModel.badgeAction(for: changed) == .reopen)

        await viewModel.tapBadge(on: changed)
        let reopened = try line(1, in: viewModel)
        #expect(repository.calls.last == .reopen(InvoiceLine.septo.id))
        #expect(reopened.productID == ReceivableProduct.septocaine.id && !reopened.isMatchChanged)
        #expect(viewModel.headline(for: reopened) == "Septocaine 4% 1:100,000")
        #expect(viewModel.badgeAction(for: reopened) == .pickAnother, "Its badge offers Which product is this? again")
    }

    /// A Possible match whose suggestion is wrong is pointed at another product through the same sheet, and its badge
    /// then reopens it to the suggestion.
    @Test func aPossibleMatchsBadgePointsItAtAnotherProduct() async throws {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        #expect(viewModel.badgeAction(for: InvoiceLine.endoKit) == .pickAnother)
        await viewModel.tapBadge(on: InvoiceLine.endoKit)
        #expect(viewModel.sheet == .match(InvoiceLine.endoKit))

        await viewModel.choose(ReceivableProduct.sealer.id, for: InvoiceLine.endoKit)
        let matched = try line(2, in: viewModel)
        #expect(repository.calls == [.match(InvoiceLine.endoKit.id, product: ReceivableProduct.sealer.id)])
        #expect(matched.state == .matched && viewModel.headline(for: matched) == "Root canal sealer")
        #expect(matched.readState == .possibleMatch && matched.readProductID == nil)
        #expect(viewModel.badgeAction(for: matched) == .reopen)

        await viewModel.tapBadge(on: matched)
        let reopened = try line(2, in: viewModel)
        #expect(reopened.state == .possibleMatch && reopened.productID == nil)
        #expect(viewModel.headline(for: reopened) == "Is this Endo file kit #15-40?", "The suggestion stays")
    }

    @Test func theBadgeOfANewProductOrAFeeDoesNothing() async {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        #expect(viewModel.badgeAction(for: InvoiceLine.tempBond) == nil, "Pick existing is a New product's way")
        #expect(viewModel.badgeAction(for: InvoiceLine.surcharge) == nil, "and Pick product a fee's")
        await viewModel.tapBadge(on: InvoiceLine.tempBond)
        await viewModel.tapBadge(on: InvoiceLine.surcharge)
        #expect(viewModel.sheet == nil)
        #expect(repository.calls.isEmpty)
    }

    @Test func whichProductIsThisWaitsWhileTheLinesChoiceIsSaved() async {
        let repository = FakeInvoiceRepository()
        let viewModel = make(repository)
        repository.duringLine = {
            await viewModel.tapBadge(on: InvoiceLine.endoKit)
        }
        await viewModel.perform(.yesMatch, on: InvoiceLine.endoKit)
        #expect(viewModel.sheet == nil)
        #expect(repository.calls == [.match(InvoiceLine.endoKit.id, product: ReceivableProduct.endoKit.id)])
    }

    @Test func theBadgeSaysWhatItDoes() {
        #expect(InvoiceReviewViewModel.badgeHint(.reopen) == "Reopens the line")
        #expect(InvoiceReviewViewModel.badgeHint(.pickAnother) == "Picks another product for this line")
    }
}
