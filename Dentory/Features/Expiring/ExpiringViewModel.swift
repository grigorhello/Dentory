import Foundation
import Observation

/// Expiring soon (f27 Admin, f28 Staff; PRD §6.7; Appendix B `expiring`): the batches expiring within 30, 60 or
/// 90 days, soonest first, with the products and value at risk; View product; and the admin's Mark disposed
/// with its Undo. The list is read once for the clinic's window and each segment filters it, so switching is
/// instant; the last list is served from the cache while a fresh one loads or the network is gone (MS-108).
/// The lines are in `ExpiringViewModel+Copy.swift`.
@MainActor
@Observable
final class ExpiringViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    /// A toast the screen shows; Undo puts a disposal back.
    struct Message: Equatable {
        let title: String
        let detail: String?
        let undoActionID: UUID?
    }

    static let windows = [30, 60, 90]

    private(set) var state: LoadState = .loading
    private(set) var list: ExpiringList?
    /// The segment on screen, in days. A tap on a segment is a choice the clinic's own window no longer overrides.
    var window: Int {
        didSet { windowIsChosen = true }
    }
    /// The batch the Mark disposed sheet is open for.
    var disposing: ExpiringBatch?
    private(set) var message: Message?
    private(set) var generalError: AppError?

    let isAdmin: Bool
    let formatters: ClinicFormatters
    private let repository: ExpiringRepository
    private let cache: ResponseCaching
    private let clinicID: UUID
    private let analytics: Analytics
    /// Home's tiles and alerts open a window; without one, the clinic's own applies once the list arrives.
    private var windowIsChosen: Bool

    init(
        repository: ExpiringRepository, cache: ResponseCaching, formatters: ClinicFormatters, clinicID: UUID,
        isAdmin: Bool, window: Int? = nil, analytics: Analytics
    ) {
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.clinicID = clinicID
        self.isAdmin = isAdmin
        self.analytics = analytics
        self.window = window.flatMap { Self.windows.contains($0) ? $0 : nil } ?? Self.windows.last ?? 90
        windowIsChosen = window != nil
        list = cache.load(ExpiringList.self, for: Self.cacheKey(clinicID))
    }

    private static func cacheKey(_ clinicID: UUID) -> CacheKey {
        CacheKey(method: "ExpiringRepository.batches", clinicID: clinicID)
    }

    /// The batches of the segment on screen: expired ones and those whose days left fit the window.
    var batches: [ExpiringBatch] {
        (list?.batches ?? []).filter { daysLeft(for: $0) <= window }
    }

    /// Days from today to the last day of the batch's month, as `days_to_expiry` counts them.
    func daysLeft(for batch: ExpiringBatch) -> Int {
        formatters.daysToExpiry(month: batch.expiryMonth)
    }

    /// Reads the list; a reload that fails keeps the last one on screen.
    func load() async {
        do {
            let fresh = try await repository.batches(clinicID: clinicID)
            cache.store(fresh, for: Self.cacheKey(clinicID))
            list = fresh
            if !windowIsChosen, Self.windows.contains(fresh.window) {
                window = fresh.window
                windowIsChosen = true
            }
            state = .loaded
        } catch {
            state = list == nil ? .failed(AppError(error)) : .loaded
        }
    }

    // MARK: - Mark disposed

    /// Admin only: the Mark disposed sheet for one batch.
    func askToDispose(_ batch: ExpiringBatch) {
        guard isAdmin else { return }
        disposing = batch
    }

    func makeDisposeViewModel(for batch: ExpiringBatch) -> DisposeBatchViewModel {
        DisposeBatchViewModel(batch: batch, repository: repository, formatters: formatters)
    }

    func keep() {
        disposing = nil
    }

    /// Closes the sheet, takes the quantity off the batch at once, toasts "Disposed" with Undo and reloads. The cached
    /// list follows too, so a disposal queued offline does not come back on the next visit and get disposed twice.
    func disposed(_ result: DisposeBatchViewModel.Disposed) async {
        disposing = nil
        analytics.track(.batchDisposed)
        if let list {
            let batches = list.batches
                .map { $0.id == result.batch.id ? $0.disposing(result.quantity) : $0 }
                .filter { $0.quantity > 0 }
            let updated = ExpiringList(window: list.window, batches: batches)
            self.list = updated
            cache.store(updated, for: Self.cacheKey(clinicID))
        }
        message = Message(
            title: "Disposed", detail: disposedDetail(result), undoActionID: result.actionID
        )
        await load()
    }

    /// The toast's Undo: the disposal comes back on the batch.
    func undoDisposal(_ actionID: UUID) async {
        do {
            try await repository.undoDisposal(actionID: actionID)
        } catch {
            generalError = AppError(error)
        }
        await load()
    }

    func clearMessage() {
        message = nil
    }

    func clearGeneralError() {
        generalError = nil
    }
}
