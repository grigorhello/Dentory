import Foundation
import Testing
@testable import Dentory

/// The Procedures tab (f11, f12): templates, shortages, the note per role and the paged history.
struct ProceduresViewModelTests {
    private let formatters = ClinicFormatters(
        currency: "USD", timeZone: TimeZone(identifier: "America/New_York") ?? .current,
        locale: Locale(identifier: "en_US"), clock: FixedClock(Session.demoNow)
    )

    private func make(
        repository: FakeProceduresRepository = FakeProceduresRepository(),
        cache: ResponseCaching = InMemoryResponseCache(),
        isAdmin: Bool = true
    ) -> ProceduresViewModel {
        ProceduresViewModel(
            repository: repository, cache: cache, formatters: formatters, clinicID: Session.demo.clinicID,
            isAdmin: isAdmin
        )
    }

    /// `count` events a minute apart, newest first, starting `offset` minutes before the demo moment.
    private func events(_ count: Int, offset: Int = 0) -> [ProcedureEventSummary] {
        (0..<count).map { index in
            ProcedureEventSummary(
                id: UUID(), name: "Filling",
                startedAt: Session.demoNow.addingTimeInterval(Double(-60 * (offset + index))),
                startedByName: "Sarah Mitchell", itemCount: 12, cancelledAt: nil
            )
        }
    }

    @Test func loadsTheTemplatesAndTheFirstPageOfHistory() async {
        let repository = FakeProceduresRepository()
        let viewModel = make(repository: repository)
        #expect(viewModel.state == .loading)
        #expect(viewModel.hasNoTemplates == false, "Nothing to say before the first answer")
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.templates.map(\.name) == ["Root canal", "Cleaning", "Filling", "Crown", "Extraction"])
        #expect(viewModel.history.map(\.name) == ["Root canal", "Cleaning", "Filling"])
        #expect(repository.templateCalls == [Session.demo.clinicID])
        #expect(repository.historyCalls == [.init(clinicID: Session.demo.clinicID, afterID: nil, limit: 30)])
        #expect(viewModel.hasMoreHistory == false, "Three rows are less than a page")
    }

    @Test func aTemplateShowsWhatIsShortAndNothingWhenCovered() {
        let viewModel = make()
        let rootCanal = ProcedureTemplateSummary.demo[0]
        #expect(viewModel.shortage(for: rootCanal) == .init(text: "1 not available", tone: .danger))
        let tight = ProcedureTemplateSummary(
            id: UUID(), name: "Crown", itemCount: 10, notAvailableCount: 0, runOutCount: 2
        )
        #expect(viewModel.shortage(for: tight) == .init(text: "2 will run out", tone: .warning))
        #expect(viewModel.shortage(for: ProcedureTemplateSummary.demo[1]) == nil)
        #expect(viewModel.itemsText(12) == "12 items")
        #expect(viewModel.itemsText(1) == "1 item")
    }

    @Test func aHistoryRowReadsWhenAndWho() {
        // The time style puts a narrow no-break space before "PM", as iOS writes times.
        let viewModel = make()
        let rootCanal = ProcedureEventSummary.demo[0]
        #expect(viewModel.historyLine(for: rootCanal) == "Oct 1\u{00A0}· 3:14\u{202F}PM\u{00A0}· Sarah")
        let cancelled = ProcedureEventSummary(
            id: UUID(), name: "Crown", startedAt: rootCanal.startedAt, startedByName: "Michael Reyes", itemCount: 10,
            cancelledAt: Session.demoNow
        )
        #expect(
            viewModel.historyLine(for: cancelled)
                == "Cancelled\u{00A0}· Oct 1\u{00A0}· 3:14\u{202F}PM\u{00A0}· Michael"
        )
        let bySomeoneGone = ProcedureEventSummary(
            id: UUID(), name: "Crown", startedAt: rootCanal.startedAt, startedByName: "", itemCount: 10,
            cancelledAt: nil
        )
        #expect(viewModel.historyLine(for: bySomeoneGone) == "Oct 1\u{00A0}· 3:14\u{202F}PM")
    }

    @Test func theNoteDependsOnTheRole() {
        #expect(make(isAdmin: true).note.contains("Pencil edits the default supplies."))
        #expect(make(isAdmin: true).note.hasSuffix("Starter quantities are templates, not clinical recommendations."))
        let staffNote = "Starting a procedure deducts its supplies right away. "
            + "Only an admin can add or edit procedure templates."
        #expect(make(isAdmin: false).note == staffNote)
    }

    @Test func theHistoryLoadsPageByPageAfterTheLastRow() async {
        let first = events(30)
        let second = events(30, offset: 30)
        let third = events(4, offset: 60)
        let repository = FakeProceduresRepository(historyPages: [.success(first), .success(second), .success(third)])
        let viewModel = make(repository: repository)
        await viewModel.load()
        #expect(viewModel.hasMoreHistory)
        await viewModel.loadMoreHistory()
        #expect(viewModel.history.count == 60)
        let nextCall = FakeProceduresRepository.HistoryCall(
            clinicID: Session.demo.clinicID, afterID: first.last?.id, limit: 30
        )
        #expect(repository.historyCalls.last == nextCall)
        await viewModel.loadMoreHistory()
        #expect(viewModel.history.count == 64)
        #expect(viewModel.hasMoreHistory == false, "A short page is the last")
        await viewModel.loadMoreHistory()
        #expect(repository.historyCalls.count == 3, "Nothing more is asked for")
    }

    @Test func aRowAlreadyListedIsNotRepeated() async {
        let first = events(30)
        let overlapping = [first[29]] + events(2, offset: 30)
        let repository = FakeProceduresRepository(historyPages: [.success(first), .success(overlapping)])
        let viewModel = make(repository: repository)
        await viewModel.load()
        await viewModel.loadMoreHistory()
        #expect(viewModel.history.count == 32)
        #expect(Set(viewModel.history.map(\.id)).count == 32)
    }

    @Test func aFailedPageKeepsTheListAndTriesAgainLater() async {
        let first = events(30)
        let repository = FakeProceduresRepository(historyPages: [
            .success(first), .failure(AppError.network), .success(events(1, offset: 30))
        ])
        let viewModel = make(repository: repository)
        await viewModel.load()
        await viewModel.loadMoreHistory()
        #expect(viewModel.history.count == 30)
        #expect(viewModel.hasMoreHistory)
        await viewModel.loadMoreHistory()
        #expect(viewModel.history.count == 31)
    }

    @Test func offlineTheLastAnswerStays() async {
        let cache = InMemoryResponseCache()
        await make(cache: cache).load()
        let offline = FakeProceduresRepository(templates: .failure(AppError.network), historyPages: [])
        let viewModel = make(repository: offline, cache: cache)
        #expect(viewModel.templates.count == 5, "The cached templates show at once")
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.history.map(\.name) == ["Root canal", "Cleaning", "Filling"])
    }

    @Test func withoutAnyAnswerTheErrorShows() async {
        let viewModel = make(repository: FakeProceduresRepository(templates: .failure(AppError.network)))
        await viewModel.load()
        #expect(viewModel.state == .failed(.network))
        #expect(viewModel.hasNoTemplates == false, "An error is not an empty clinic")
    }

    @Test func aClinicWithoutTemplatesSaysSo() async {
        let empty = FakeProceduresRepository(templates: .success([]), historyPages: [.success([])])
        let viewModel = make(repository: empty)
        await viewModel.load()
        #expect(viewModel.hasNoTemplates)
        #expect(viewModel.history.isEmpty)
    }
}
