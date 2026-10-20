import Foundation
import Testing
@testable import Dentory

@MainActor
struct HomeViewModelTests {
    private func makeViewModel(
        repository: FakeHomeRepository, cache: ResponseCaching = InMemoryResponseCache()
    ) -> HomeViewModel {
        HomeViewModel(repository: repository, cache: cache, clinicID: Session.demo.clinicID)
    }

    @Test func loadsTheSummaryForTheClinic() async {
        let repository = FakeHomeRepository()
        let viewModel = makeViewModel(repository: repository)
        #expect(viewModel.state == .loading)
        #expect(viewModel.summary == nil)
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.summary == .demo)
        #expect(repository.calls == [Session.demo.clinicID])
    }

    @Test func aFailureWithNothingCachedIsShown() async {
        let viewModel = makeViewModel(repository: FakeHomeRepository(result: .failure(AppError.network)))
        await viewModel.load()
        #expect(viewModel.state == .failed(.network))
        #expect(viewModel.summary == nil)
    }

    @Test func theLastSummaryIsServedFromTheCacheWhenOffline() async {
        let cache = InMemoryResponseCache()
        let first = makeViewModel(repository: FakeHomeRepository(), cache: cache)
        await first.load()

        let relaunched = makeViewModel(repository: FakeHomeRepository(result: .failure(AppError.network)), cache: cache)
        #expect(relaunched.summary == .demo, "The cached summary shows before any load")
        await relaunched.load()
        #expect(relaunched.state == .loaded)
        #expect(relaunched.summary == .demo)
    }

    @Test func zeroCountsAreInk() {
        #expect(HomeViewModel.tone(for: 0, nonZero: .warning) == .neutral)
        #expect(HomeViewModel.tone(for: 3, nonZero: .warning) == .warning)
        #expect(HomeViewModel.tone(for: 2, nonZero: .danger) == .danger)
    }

    @Test func theLatestProcedureIsAbsentForANewClinic() async {
        let viewModel = makeViewModel(repository: FakeHomeRepository(result: .success(.empty)))
        await viewModel.load()
        #expect(viewModel.summary?.latestProcedure == nil)
        #expect(viewModel.summary?.hasUnseenAlerts == false)
    }

    @Test func firstNamesComeFromTheFullName() {
        #expect(PersonName.first(of: "Sarah Chen") == "Sarah")
        #expect(PersonName.first(of: "Dr. Kim") == "Dr.")
        #expect(PersonName.first(of: "") == "")
    }
}
