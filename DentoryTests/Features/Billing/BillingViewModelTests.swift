import Foundation
import Testing
@testable import Dentory

/// Billing (f34, MS-140, MS-100 D18): the trial and plan card, the promotion's price, the payment method's status and
/// where its link goes, the rows, and a card added from the email showing on the next load.
@MainActor
struct BillingViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "CAD", timeZone: TimeZone(identifier: "America/Toronto") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let day: TimeInterval = 24 * 60 * 60

    private func summary(
        trialEndsIn days: Double = 96, status: SubscriptionStatus = .trialing, subscribed: Bool = false,
        promo: Bool = true, card: (String, String?)? = nil, periodEnd: Date? = nil, invoices: Int = 0
    ) -> BillingSummary {
        BillingSummary(
            trialEndsAt: Session.demoNow.addingTimeInterval(days * day), subscriptionStatus: status,
            hasSubscription: subscribed, promoLifetime50: promo, cardBrand: card?.0, cardLast4: card?.1,
            currentPeriodEnd: periodEnd, invoiceCount: invoices, billingEmail: "owner@smiledental.ca",
            billingEmailCount: 1
        )
    }

    private func make(_ repository: FakeBillingRepository, cache: ResponseCaching = InMemoryResponseCache())
        -> BillingViewModel {
        BillingViewModel(
            clinicID: Session.demo.clinicID, repository: repository, cache: cache, formatters: formatters
        )
    }

    private func loaded(_ answer: BillingSummary) async -> BillingViewModel {
        let viewModel = make(FakeBillingRepository(answer))
        await viewModel.load()
        return viewModel
    }

    @Test func theTrialReadsAsF34() async {
        let viewModel = await loaded(BillingSummary.demo(hasCard: true))
        #expect(viewModel.eyebrow == "Free trial")
        #expect(viewModel.headline.value == "3 months")
        #expect(viewModel.headline.suffix == "free")
        #expect(viewModel.dateLine == "Ends January 6, 2027")
        #expect(viewModel.showsAfterTrialPrice)
        #expect(viewModel.regularPriceText == "$99")
        #expect(viewModel.monthlyPriceText == "$49.50 / month")
        #expect(viewModel.paymentMethodText == "Visa ·· 4242")
        #expect(viewModel.paymentMethodNote == nil)
        #expect(viewModel.invoicesText == "None yet")
        #expect(viewModel.billingEmailText == "owner@smiledental.ca")
    }

    @Test func theLastThirtyDaysCountDown() async {
        #expect(await loaded(summary(trialEndsIn: 12)).headline.value == "12 days")
        #expect(await loaded(summary(trialEndsIn: 12)).headline.suffix == "left")
        #expect(await loaded(summary(trialEndsIn: 1)).headline.value == "1 day")
        #expect(await loaded(summary(trialEndsIn: 0.25)).headline.value == "Last day", "Ends later today")
        #expect(await loaded(summary(trialEndsIn: 31)).headline.value == "3 months")
    }

    @Test func withoutThePromotionThePriceIsNinetyNine() async {
        let viewModel = await loaded(summary(promo: false))
        #expect(viewModel.isPromo == false)
        #expect(viewModel.monthlyPriceText == "$99 / month")
    }

    @Test func aTrialThatEndedWithoutACardSaysSoAndWhereTheLinkGoes() async {
        let viewModel = await loaded(summary(trialEndsIn: -3))
        #expect(viewModel.cardKind == .trialEnded)
        #expect(viewModel.eyebrow == "Free trial")
        #expect(viewModel.headline.value == "Trial ended")
        #expect(viewModel.headline.suffix == nil)
        #expect(viewModel.dateLine == "Ended September 29, 2026")
        #expect(viewModel.paymentMethodText == "Not set")
        #expect(viewModel.paymentMethodNote == "The link to add a card is emailed to owner@smiledental.ca.")
    }

    @Test func aSubscriptionThatEndedAfterTheTrialSaysSo() async {
        let viewModel = await loaded(summary(trialEndsIn: -40, status: .canceled, card: ("visa", "4242")))
        #expect(viewModel.cardKind == .subscriptionEnded)
        #expect(viewModel.headline.value == "Subscription ended")
        #expect(viewModel.dateLine == nil)
        #expect(viewModel.showsAfterTrialPrice == false)
    }

    @Test func afterTheTrialThePlanShowsItsPriceAndNextPayment() async {
        let next = Session.demoNow.addingTimeInterval(20 * day)
        let viewModel = await loaded(
            summary(trialEndsIn: -10, status: .active, subscribed: true, card: ("mastercard", "5454"), periodEnd: next,
                    invoices: 3)
        )
        #expect(viewModel.cardKind == .plan)
        #expect(viewModel.eyebrow == "Plan")
        #expect(viewModel.headline.value == "$49.50")
        #expect(viewModel.headline.suffix == "/ month")
        #expect(viewModel.dateLine == "Next payment October 22, 2026")
        #expect(viewModel.showsAfterTrialPrice == false)
        #expect(viewModel.cardText == "Mastercard ·· 5454")
        #expect(viewModel.invoicesText == "3")
        let failed = await loaded(summary(trialEndsIn: -10, status: .pastDue, subscribed: true, card: ("visa", "4242")))
        #expect(failed.dateLine == "The last payment failed. Update the card from your billing email.")
    }

    @Test func cardBrandsReadAsPeopleWriteThem() {
        #expect(BillingViewModel.brandName("amex") == "Amex")
        #expect(BillingViewModel.brandName("diners") == "Diners Club")
        #expect(BillingViewModel.brandName("cartes_bancaires") == "Cartes Bancaires")
        #expect(BillingViewModel.usd(99) == "$99")
        #expect(BillingViewModel.usd(49.5) == "$49.50")
    }

    @Test func theCachedSummaryShowsOfflineAndAFailureWithoutOneSaysWhy() async {
        let cache = InMemoryResponseCache()
        let first = make(FakeBillingRepository(summary()), cache: cache)
        await first.load()
        let offline = FakeBillingRepository(summary())
        offline.failure = AppError.network
        let second = make(offline, cache: cache)
        #expect(second.summary != nil, "From the cache before loading")
        await second.load()
        #expect(second.state == .loaded)
        let empty = make(offline)
        await empty.load()
        #expect(empty.state == .failed(.network))
    }

    @Test func aCardAddedFromTheEmailShowsOnTheNextLoad() async {
        let repository = FakeBillingRepository(summary())
        let viewModel = make(repository)
        await viewModel.load()
        #expect(viewModel.paymentMethodText == "Not set")
        repository.summary = summary(status: .active, subscribed: true, card: ("visa", "4242"))
        await viewModel.load()
        #expect(viewModel.paymentMethodText == "Visa ·· 4242", "Without a restart")
    }
}
