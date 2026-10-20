import Foundation
import Testing
@testable import Dentory

/// Activity (f8): each alert's sentence, dot and time, where it leads, the seen marker and the cache.
struct ActivityViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        _ repository: FakeActivityRepository = FakeActivityRepository(),
        cache: ResponseCaching = InMemoryResponseCache()
    ) async -> ActivityViewModel {
        let viewModel = ActivityViewModel(
            repository: repository, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID
        )
        await viewModel.load()
        return viewModel
    }

    private func alert(
        _ kind: ActivityAlert.Kind, name: String? = "Endo file kit #15-40", quantity: Decimal = 1,
        unopened: Decimal = 0, minimum: Decimal = 3, tracking: TrackingMode = .countable, lot: String? = nil,
        month: CalendarDay? = nil, batches: Int = 0, supplier: String? = nil, openedAt: Date = Session.demoNow
    ) -> ActivityAlert {
        ActivityAlert(
            id: UUID(), kind: kind, openedAt: openedAt, thresholdDays: nil, productID: UUID(), name: name,
            unit: "kits", tracking: tracking, minimum: minimum, quantity: quantity, unopened: unopened,
            batchID: nil, lot: lot, expiryMonth: month, expiringBatches: batches, invoiceID: nil, supplier: supplier
        )
    }

    @Test func f8sThreeAlertsReadAsDrawn() async {
        let viewModel = await make()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.segmentOptions.map(\.text) == ["Alerts · 3", "History"])
        #expect(viewModel.alerts.map(viewModel.sentence(for:)) == [
            "Rubber dam latex-free is out of stock.",
            "Bonding agent expires in 59 days.",
            "Gutta percha F2 is missing expiry information."
        ])
        #expect(viewModel.alerts.map(viewModel.whenText(for:)) == ["Today · 8:40\u{202F}AM", "Yesterday", "Yesterday"])
        #expect(viewModel.alerts.map(viewModel.dotTone(for:)) == [.danger, .warning, .info])
    }

    @Test func lowSaysWhatIsLeftAgainstTheMinimum() async {
        let viewModel = await make()
        #expect(viewModel.sentence(for: alert(.low)) == "Endo file kit #15-40 is low · 1 left, minimum 3.")
        let composite = alert(.low, name: "Composite A2", quantity: 3, unopened: 1, minimum: 2, tracking: .multiUse)
        #expect(viewModel.sentence(for: composite) == "Composite A2 is low · 1 left, minimum 2.", "Unopened counts")
        #expect(viewModel.dotTone(for: composite) == .warning)
    }

    @Test func expiringNamesTheLotOnlyWhenSeveralBatchesAre() async {
        let viewModel = await make()
        let december = CalendarDay(year: 2026, month: 12, day: 1)
        let one = alert(.expiring, name: "Septocaine 4% 1:100,000", lot: "B441", month: december, batches: 1)
        let two = alert(.expiring, name: "Septocaine 4% 1:100,000", lot: "B441", month: december, batches: 2)
        #expect(viewModel.sentence(for: one) == "Septocaine 4% 1:100,000 expires in 90 days.")
        #expect(viewModel.sentence(for: two) == "Septocaine 4% 1:100,000 lot B441 expires in 90 days.")
    }

    @Test func soonAndPastExpiriesReadAndColourAsDanger() async {
        let viewModel = await make()
        let october = alert(.expiring, name: "Etch gel 37%", month: CalendarDay(year: 2026, month: 10, day: 1))
        let september = alert(.expiring, name: "Etch gel 37%", month: CalendarDay(year: 2026, month: 9, day: 1))
        #expect(viewModel.sentence(for: october) == "Etch gel 37% expires in 29 days.")
        #expect(viewModel.dotTone(for: october) == .danger, "Within 30 days")
        #expect(viewModel.sentence(for: september) == "Etch gel 37% has expired.")
        #expect(viewModel.dotTone(for: september) == .danger)
    }

    @Test func aDeliveryNamesItsSupplier() async {
        let viewModel = await make()
        let delivery = alert(.invoiceReady, name: nil, supplier: "Patterson")
        #expect(viewModel.sentence(for: delivery) == "Delivery from Patterson is read and waiting for review.")
        let unnamed = alert(.invoiceReady, name: nil)
        #expect(viewModel.sentence(for: unnamed) == "A delivery is read and waiting for review.")
        #expect(viewModel.dotTone(for: delivery) == .info)
        #expect(viewModel.destination(for: delivery) == .delivery)
    }

    @Test func olderAlertsShowTheirDay() async {
        let viewModel = await make()
        let older = alert(.missingExpiry, openedAt: Date(timeIntervalSince1970: 1_790_640_000)) // Sep 28
        #expect(viewModel.whenText(for: older) == "Sep 28")
    }

    @Test func aProductsAlertOpensTheProduct() async throws {
        let viewModel = await make()
        let rubberDam = try #require(viewModel.alerts.first)
        #expect(viewModel.destination(for: rubberDam) == rubberDam.productID.map(ActivityViewModel.Destination.product))
    }

    @Test func lookingAtAlertsMarksThemSeen() async {
        let repository = FakeActivityRepository()
        _ = await make(repository)
        #expect(repository.seenCalls == 1)
    }

    @Test func aFailedSeenMarkLeavesTheAlertsOnScreen() async {
        let repository = FakeActivityRepository()
        repository.markSeenError = AppError.network
        let viewModel = await make(repository)
        #expect(viewModel.state == .loaded)
        #expect(viewModel.alerts.count == 3)
    }

    @Test func nothingOpenIsTheEmptyState() async {
        let repository = FakeActivityRepository()
        repository.alertsResult = .success([])
        let viewModel = await make(repository)
        #expect(viewModel.alerts.isEmpty)
        #expect(viewModel.segmentOptions.first?.text == "Alerts · 0")
        #expect(ActivityViewModel.emptyText == "Nothing needs attention.")
    }

    @Test func offlineTheLastAlertsShowFromTheCache() async {
        let cache = InMemoryResponseCache()
        _ = await make(cache: cache)
        let offline = FakeActivityRepository()
        offline.alertsResult = .failure(AppError.network)
        let viewModel = ActivityViewModel(
            repository: offline, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID
        )
        #expect(viewModel.alerts.count == 3, "The cached alerts show at once")
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(offline.seenCalls == 0, "Nothing fresh was seen")
    }

    @Test func withoutAnyAlertsTheErrorShows() async {
        let repository = FakeActivityRepository()
        repository.alertsResult = .failure(AppError.network)
        let viewModel = await make(repository)
        #expect(viewModel.state == .failed(.network))
    }
}
