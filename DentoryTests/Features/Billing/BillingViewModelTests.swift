import Foundation
import Testing
@testable import Dentory

/// Billing (f34, MS-140): the trial and plan card, the promotion's price, the card with Add or Change, the rows, the
/// Stripe page for each case and the wait for the webhook once it closes.
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

    private func make(_ repository: FakeBillingRepository, cache: ResponseCaching = InMemoryResponseCache()) -> (
        BillingViewModel, PauseLog
    ) {
        let log = PauseLog()
        let viewModel = BillingViewModel(
            clinicID: Session.demo.clinicID, repository: repository, cache: cache, formatters: formatters,
            pause: { await log.record($0) }
        )
        return (viewModel, log)
    }

    private func loaded(_ answer: BillingSummary) async -> BillingViewModel {
        let (viewModel, _) = make(FakeBillingRepository([answer]))
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
        #expect(viewModel.cardText == "Visa ·· 4242")
        #expect(viewModel.paymentActionTitle == "Change")
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

    @Test func aTrialThatEndedWithoutACardSaysSoAndOffersAdd() async {
        let viewModel = await loaded(summary(trialEndsIn: -3))
        #expect(viewModel.cardKind == .trialEnded)
        #expect(viewModel.eyebrow == "Free trial")
        #expect(viewModel.headline.value == "Trial ended")
        #expect(viewModel.headline.suffix == nil)
        #expect(viewModel.dateLine == "Ended September 29, 2026")
        #expect(viewModel.cardText == nil)
        #expect(viewModel.paymentActionTitle == "Add")
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
        #expect(failed.dateLine == "The last payment failed. Change the card.")
    }

    @Test func cardBrandsReadAsPeopleWriteThem() {
        #expect(BillingViewModel.brandName("amex") == "Amex")
        #expect(BillingViewModel.brandName("diners") == "Diners Club")
        #expect(BillingViewModel.brandName("cartes_bancaires") == "Cartes Bancaires")
        #expect(BillingViewModel.usd(99) == "$99")
        #expect(BillingViewModel.usd(49.5) == "$49.50")
    }

    @Test func addOpensCheckoutAndChangeTheCustomerPortal() async {
        let repository = FakeBillingRepository([summary()])
        let (viewModel, _) = make(repository)
        await viewModel.load()
        await viewModel.managePayment()
        #expect(repository.pageRequests == [false], "Checkout without a subscription")
        #expect(viewModel.paymentPage?.url.absoluteString == "https://checkout.stripe.com/c/pay/cs_test_1")

        let subscribed = FakeBillingRepository([summary(status: .active, subscribed: true, card: ("visa", "4242"))])
        let (portal, _) = make(subscribed)
        await portal.load()
        await portal.managePayment()
        #expect(subscribed.pageRequests == [true], "The Customer Portal with one")
    }

    @Test func afterThePageClosesBillingWaitsForTheWebhook() async {
        let before = summary()
        let after = summary(status: .active, subscribed: true, card: ("visa", "4242"))
        let repository = FakeBillingRepository([before, before, before, after])
        let (viewModel, log) = make(repository)
        await viewModel.load()
        await viewModel.managePayment()
        await viewModel.paymentPageClosed()
        #expect(viewModel.paymentPage == nil)
        #expect(viewModel.cardText == "Visa ·· 4242", "The webhook's card shows without a restart")
        #expect(repository.loads == 4, "It stops once the card is there")
        #expect(await log.pauses == [.seconds(2), .seconds(3)])
    }

    @Test func aCancelledPageEndsTheChecksQuietly() async {
        let repository = FakeBillingRepository([summary()])
        let (viewModel, log) = make(repository)
        await viewModel.load()
        await viewModel.paymentPageClosed()
        #expect(repository.loads == 1 + BillingViewModel.webhookChecks.count)
        #expect(await log.pauses.count == BillingViewModel.webhookChecks.count - 1)
        #expect(viewModel.message == nil)
    }

    @Test func theDemoClinicAddsItsCardWithoutAPage() async {
        let repository = FakeBillingRepository([summary(), summary(card: ("visa", "4242"))])
        repository.page = .success(nil)
        let (viewModel, _) = make(repository)
        await viewModel.load()
        await viewModel.managePayment()
        #expect(viewModel.paymentPage == nil)
        #expect(viewModel.cardText == "Visa ·· 4242")
    }

    @Test func aRefusedPageIsSaid() async {
        let repository = FakeBillingRepository([summary()])
        let sentence = "Billing isn't set up yet. Try again later."
        repository.page = .failure(AppError.validation(field: nil, message: sentence))
        let (viewModel, _) = make(repository)
        await viewModel.load()
        await viewModel.managePayment()
        #expect(viewModel.message == "Billing isn't set up yet. Try again later.")
        #expect(viewModel.isOpeningPayment == false)
    }

    @Test func theCachedSummaryShowsOfflineAndAFailureWithoutOneSaysWhy() async {
        let cache = InMemoryResponseCache()
        let (first, _) = make(FakeBillingRepository([summary()]), cache: cache)
        await first.load()
        let offline = FakeBillingRepository([summary()])
        offline.failure = AppError.network
        let (second, _) = make(offline, cache: cache)
        #expect(second.summary != nil, "From the cache before loading")
        await second.load()
        #expect(second.state == .loaded)
        let (empty, _) = make(offline)
        await empty.load()
        #expect(empty.state == .failed(.network))
    }
}

/// The pauses Billing took between checks.
actor PauseLog {
    private(set) var pauses: [Duration] = []

    func record(_ pause: Duration) {
        pauses.append(pause)
    }
}
