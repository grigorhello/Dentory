import Foundation
import Observation

/// Loads the Home summary, serving the cached one while a fresh one is on its way or the network is gone.
@MainActor
@Observable
final class HomeViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    private(set) var state: LoadState = .loading
    private(set) var summary: HomeSummary?

    private let repository: HomeRepository
    private let cache: ResponseCaching
    private let clinicID: UUID
    private let userID: UUID

    init(repository: HomeRepository, cache: ResponseCaching, clinicID: UUID, userID: UUID) {
        self.repository = repository
        self.cache = cache
        self.clinicID = clinicID
        self.userID = userID
        summary = cache.load(HomeSummary.self, for: cacheKey)
    }

    private var cacheKey: CacheKey { CacheKey(method: "HomeRepository.summary", clinicID: clinicID) }

    func load() async {
        do {
            let fresh = try await repository.summary(clinicID: clinicID, userID: userID)
            summary = fresh
            cache.store(fresh, for: cacheKey)
            state = .loaded
        } catch {
            let appError = AppError(error)
            // The last answer stays on screen; the banner says why it may be stale.
            state = summary == nil ? .failed(appError) : .loaded
        }
    }

    /// A zero count is drawn in ink, not in its status color (PRD §6.2).
    static func tone(for count: Int, nonZero: StatusTone) -> StatusTone {
        count == 0 ? .neutral : nonZero
    }
}
