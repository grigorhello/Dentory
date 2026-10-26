import Foundation
import Testing
@testable import Dentory

/// History (f9): days, each row's words, the chips, one product's history, the pages and the cache, and the invoice a
/// receipt opens on an admin's Activity (MS-131).
@MainActor
struct ActivityHistoryViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        repository: FakeActivityRepository = FakeActivityRepository(),
        cache: ResponseCaching = InMemoryResponseCache(),
        productID: UUID? = nil, opensInvoices: Bool = false
    ) -> ActivityHistoryViewModel {
        ActivityHistoryViewModel(
            repository: repository, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID,
            productID: productID, opensInvoices: opensInvoices
        )
    }

    /// An entry `hoursAgo` before the demo moment.
    private func entry(
        _ type: TransactionType, _ subject: String = "Septocaine 4% 1:100,000", product: UUID? = UUID(),
        delta: Decimal = -2, before: Decimal? = nil, refType: String = "manual", label: String? = nil,
        reason: String? = nil, note: String? = nil, isEdit: Bool = false, by name: String = "Sarah Mitchell",
        hoursAgo: Double = 1
    ) -> ActivityHistoryEntry {
        ActivityHistoryEntry(
            id: UUID(), at: Session.demoNow.addingTimeInterval(-hoursAgo * 3_600), type: type, subject: subject,
            productID: product, delta: delta, qtyBefore: before, qtyAfter: before.map { $0 + delta },
            refType: refType, refLabel: label, reason: reason, note: note, isEdit: isEdit, byName: name
        )
    }

    @Test func aReceiptOpensItsInvoiceOnlyOnAnAdminsActivity() {
        var receipt = entry(.receiving, delta: 250, refType: "invoice", label: "Invoice INV-10092")
        let invoiceID = UUID()
        receipt.invoiceID = invoiceID
        let count = entry(.count, before: 43)
        #expect(make(opensInvoices: true).invoiceID(for: receipt) == invoiceID)
        #expect(make(opensInvoices: true).invoiceID(for: count) == nil, "Only a receipt opens an invoice")
        #expect(make().invoiceID(for: receipt) == nil, "Staff, and a product's history, open nothing")
    }

    @Test func theDependenciesLetOnlyAnAdminsActivityOpenInvoices() {
        let dependencies = AppDependencies.preview()
        #expect(dependencies.makeActivityHistoryViewModel(session: .demo, productID: nil).opensInvoices)
        #expect(!dependencies.makeActivityHistoryViewModel(session: .demo(role: .staff), productID: nil).opensInvoices)
        #expect(!dependencies.makeActivityHistoryViewModel(session: .demo, productID: UUID()).opensInvoices)
    }

    @Test func loadsTheFirstPageAndGroupsItByDay() async {
        let repository = FakeActivityRepository()
        let viewModel = make(repository: repository)
        #expect(viewModel.state == .loading)
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(repository.historyCalls == [.init(filter: .all, productID: nil, afterID: nil, limit: 50)])
        #expect(viewModel.days.map(\.title) == ["Yesterday", "Sep 30", "Sep 29", "Sep 28", "Sep 26"])
        #expect(viewModel.days.first?.entries.map(\.subject) == ["Septocaine 4% 1:100,000", "Root canal", "Cleaning"])
        #expect(viewModel.hasMore == false, "Nine rows are less than a page")
    }

    @Test func eachRowSaysWhatHappened() {
        let viewModel = make()
        let procedure = entry(.procedure, "Root canal", product: nil, refType: "procedure_event")
        #expect(viewModel.reasonText(for: procedure) == "Procedure started")
        let edit = entry(.procedure, "Root canal", product: nil, refType: "procedure_event", isEdit: true)
        #expect(viewModel.reasonText(for: edit) == "Edited usage")
        let cancelled = entry(
            .cancellation, "Crown", product: nil, refType: "procedure_event", note: "Logged by mistake"
        )
        #expect(viewModel.reasonText(for: cancelled) == "Cancelled · Logged by mistake")
        #expect(viewModel.reasonText(for: entry(.cancellation, "Crown", product: nil)) == "Cancelled")
        // One product's history names the procedure on the reason line (f9's Septocaine row).
        #expect(viewModel.reasonText(for: entry(.procedure, label: "Root canal")) == "Root canal")
        #expect(viewModel.reasonText(for: entry(.cancellation, label: "Crown")) == "Cancelled · Crown")
        #expect(viewModel.reasonText(for: entry(.receiving, label: "Invoice INV-10092")) == "Invoice INV-10092")
        #expect(viewModel.reasonText(for: entry(.count, label: "Physical count")) == "Physical count")
        #expect(viewModel.reasonText(for: entry(.adjustment, label: "Damaged", reason: "Damaged")) == "Damaged")
        #expect(viewModel.reasonText(for: entry(.adjustment, label: "Opened a new bottle")) == "Opened a new bottle")
        let disposed = entry(.disposal, label: "Mark disposed", reason: "Expired")
        #expect(viewModel.reasonText(for: disposed) == "Disposed · Expired")
        let undo = entry(.adjustment, refType: "undo", label: "Undo · Damaged", reason: "Damaged")
        #expect(viewModel.reasonText(for: undo) == "Undo · Damaged")
    }

    @Test func theChangeReadsInItsColor() {
        let viewModel = make()
        let received = entry(.receiving, delta: 4)
        #expect(viewModel.deltaText(for: received) == "+4")
        #expect(viewModel.deltaTone(for: received) == .success)
        let used = entry(.procedure, product: nil, delta: -6)
        #expect(viewModel.deltaText(for: used) == "\u{2212}6", "A real minus sign")
        #expect(viewModel.deltaTone(for: used) == .danger)
        let counted = entry(.count, delta: -2, before: 43)
        #expect(viewModel.deltaText(for: counted) == "43 → 41")
        #expect(viewModel.deltaTone(for: counted) == nil, "A count is ink")
        let opened = entry(.adjustment, delta: 0)
        #expect(viewModel.deltaText(for: opened) == "0", "A bottle opened reads as Product detail's card has it")
        #expect(viewModel.deltaTone(for: opened) == nil)
        #expect(viewModel.deltaText(for: entry(.receiving, delta: Decimal(25) / 10)) == "+2.5")
    }

    @Test func whoAndWhenOnTheirOwnLine() {
        let viewModel = make()
        // The demo moment is 5:27 AM in New York; two hours before reads 3:27 AM.
        #expect(viewModel.whoText(for: entry(.receiving, hoursAgo: 2)) == "Sarah · 3:27\u{202F}AM")
        #expect(viewModel.whoText(for: entry(.receiving, by: "", hoursAgo: 2)) == "3:27\u{202F}AM", "Someone who left")
    }

    @Test func daysReadTodayYesterdayThenTheDate() {
        let viewModel = make()
        let now = Session.demoNow
        #expect(viewModel.dayTitle(for: now) == "Today")
        #expect(viewModel.dayTitle(for: now.addingTimeInterval(-86_400)) == "Yesterday")
        #expect(viewModel.dayTitle(for: now.addingTimeInterval(-2 * 86_400)) == "Sep 30")
        #expect(viewModel.dayTitle(for: now.addingTimeInterval(-365 * 86_400)) == "Oct 2, 2025", "Another year says so")
    }

    @Test func aChipReloadsAndAnOlderAnswerDoesNotWin() async {
        let counts = [entry(.count, "Nitrile gloves M", delta: -2, before: 16)]
        let repository = FakeActivityRepository()
        repository.historyPages = [.success(ActivityHistoryEntry.demo(productID: nil)), .success(counts)]
        let viewModel = make(repository: repository)
        await viewModel.load()
        viewModel.filter = .counts
        await viewModel.load()
        #expect(repository.historyCalls.last == .init(filter: .counts, productID: nil, afterID: nil, limit: 50))
        #expect(viewModel.entries == counts)
        #expect(viewModel.emptyText == "No counts yet.")

        // A page asked for under Counts that arrives after Receiving was chosen is dropped.
        let slow = FakeActivityRepository()
        slow.historyPages = [.success(counts)]
        let late = make(repository: slow)
        late.filter = .counts
        slow.whileHistoryLoads = { late.filter = .receiving }
        await late.load()
        #expect(late.entries.isEmpty, "Counts' rows never show under Receiving")
        #expect(late.filter == .receiving)
    }

    @Test func oneProductsHistoryAsksForItsRows() async {
        let repository = FakeActivityRepository()
        let septocaine = ProductSummary.demo[0].id
        repository.historyPages = [.success(ActivityHistoryEntry.demo(productID: septocaine))]
        let viewModel = make(repository: repository, productID: septocaine)
        await viewModel.load()
        #expect(repository.historyCalls.first?.productID == septocaine)
        #expect(viewModel.entries.map { viewModel.reasonText(for: $0) } == [
            "Physical count", "Root canal", "Invoice INV-10092"
        ], "Product detail's three rows (f20)")
        #expect(make(productID: septocaine).emptyText == "Nothing recorded for this product yet.")
        #expect(make().emptyText == "Nothing recorded yet.")
    }

    @Test func theNextPageContinuesAfterTheLastRow() async {
        let full = (0..<50).map { entry(.receiving, delta: 1, hoursAgo: Double($0)) }
        let next = [entry(.receiving, delta: 1, hoursAgo: 60), full[49]]
        let repository = FakeActivityRepository()
        repository.historyPages = [.success(full), .success(next)]
        let viewModel = make(repository: repository)
        await viewModel.load()
        #expect(viewModel.hasMore)
        await viewModel.loadMore()
        #expect(repository.historyCalls.last?.afterID == full[49].id)
        #expect(viewModel.entries.count == 51, "A row already listed is not repeated")
        #expect(viewModel.hasMore == false)
    }

    @Test func theLastPageShowsOfflineAndAFailureWithoutOneSaysWhy() async {
        let cache = InMemoryResponseCache()
        await make(cache: cache).load()
        let offline = FakeActivityRepository()
        offline.historyPages = [.failure(AppError.network)]
        let viewModel = make(repository: offline, cache: cache)
        #expect(viewModel.entries.count == 9, "The cached page shows at once")
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        let nothingCached = FakeActivityRepository()
        nothingCached.historyPages = [.failure(AppError.network)]
        let failed = make(repository: nothingCached)
        await failed.load()
        #expect(failed.state == .failed(.network))
    }

    @Test func aLoadCancelledByLeavingTheSegmentIsNoFailure() async {
        let repository = FakeActivityRepository()
        repository.historyPages = [.failure(AppError.network)]
        let viewModel = make(repository: repository)
        let load = Task { await viewModel.load() }
        load.cancel()
        await load.value
        #expect(viewModel.state == .loading, "No offline notice flashes when History shows again")
    }
}
