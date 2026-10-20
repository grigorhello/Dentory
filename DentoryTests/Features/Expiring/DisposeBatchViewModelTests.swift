import Foundation
import Testing
@testable import Dentory

/// Mark disposed (Appendix C `dispose`): the whole batch by default, never more, one submission, a refusal kept.
struct DisposeBatchViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )
    private let septocaine = ExpiringBatch.demo[1]

    private func make(_ repository: FakeExpiringRepository = FakeExpiringRepository()) -> DisposeBatchViewModel {
        DisposeBatchViewModel(batch: septocaine, repository: repository, formatters: formatters)
    }

    @Test func theSheetOpensOnTheWholeBatch() {
        let viewModel = make()
        #expect(viewModel.caption == "Septocaine 4% 1:100,000 · lot B441. Removed with reason Expired.")
        #expect(viewModel.quantityText == "34")
        #expect(viewModel.canDispose)
    }

    /// A batch of 1,000 opens on "1000", which reads back whole; typed separators read too.
    @Test func aThousandIsDisposedWhole() async throws {
        let gloves = ExpiringBatch(
            id: UUID(), productID: UUID(), name: "Nitrile gloves M", unit: "gloves", tracking: .countable,
            quantity: 1000, lot: "G7", expiryMonth: CalendarDay(year: 2026, month: 12, day: 1), value: 90
        )
        let repository = FakeExpiringRepository()
        let viewModel = DisposeBatchViewModel(batch: gloves, repository: repository, formatters: formatters)
        #expect(viewModel.quantityText == "1000")
        #expect(viewModel.quantity == 1000)
        await viewModel.dispose()
        #expect(repository.disposals.first?.quantity == 1000)
        viewModel.quantityText = "1,000"
        #expect(viewModel.quantity == 1000)
        #expect(viewModel.quantityError == nil)
    }

    @Test func aBatchWithoutALotNamesTheProductOnly() {
        let batch = ExpiringBatch(
            id: UUID(), productID: UUID(), name: "Gauze", unit: "packs", tracking: .countable, quantity: 2, lot: nil,
            expiryMonth: CalendarDay(year: 2026, month: 12, day: 1), value: 3
        )
        let viewModel = DisposeBatchViewModel(
            batch: batch, repository: FakeExpiringRepository(), formatters: formatters
        )
        #expect(viewModel.caption == "Gauze. Removed with reason Expired.")
    }

    @Test func neverMoreThanTheBatchNorNothing() {
        let viewModel = make()
        viewModel.quantityText = "35"
        #expect(viewModel.quantityError == "At most 34 cartridges.")
        #expect(!viewModel.canDispose)
        viewModel.quantityText = "0"
        #expect(viewModel.quantityError == "Enter a quantity above 0.")
        #expect(!viewModel.canDispose)
        viewModel.quantityText = "abc"
        #expect(viewModel.quantityError == nil, "Nothing to say until it is a number")
        #expect(!viewModel.canDispose)
        viewModel.quantityText = "10"
        #expect(viewModel.quantityError == nil)
        #expect(viewModel.canDispose)
    }

    @Test func disposingSendsTheQuantityAndCarriesTheActionForUndo() async throws {
        let repository = FakeExpiringRepository()
        let actionID = UUID()
        repository.disposeResult = .success(.applied(actionID: actionID))
        let viewModel = make(repository)
        viewModel.quantityText = "12"
        await viewModel.dispose()
        let disposal = try #require(repository.disposals.first)
        #expect(disposal.batchID == septocaine.id)
        #expect(disposal.quantity == 12)
        #expect(viewModel.disposed == .init(batch: septocaine, quantity: 12, actionID: actionID))
    }

    @Test func aQueuedDisposalHasNoUndo() async {
        let repository = FakeExpiringRepository()
        repository.disposeResult = .success(.queued)
        let viewModel = make(repository)
        await viewModel.dispose()
        #expect(viewModel.disposed == .init(batch: septocaine, quantity: 34, actionID: nil))
    }

    @Test func aRefusalStaysInTheSheet() async {
        let repository = FakeExpiringRepository()
        repository.disposeResult = .failure(AppError.forbidden)
        let viewModel = make(repository)
        await viewModel.dispose()
        #expect(viewModel.disposed == nil)
        #expect(viewModel.generalError == .forbidden)
        #expect(viewModel.quantityText == "34", "The input is kept")
    }
}
