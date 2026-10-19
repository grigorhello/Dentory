import Foundation
import Observation

/// The Procedures tab (f11 Admin, f12 Staff): the clinic's templates with their shortages, the note under them,
/// and every past procedure, newest first, a page at a time. The last answer is served from the cache while a
/// fresh one loads or the network is gone (MS-108).
@MainActor
@Observable
final class ProceduresViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    /// The warning line of a template row: "1 not available" in danger, else "2 will run out" in warning.
    struct Shortage: Equatable {
        let text: String
        let tone: StatusTone
    }

    /// How many past procedures one page brings.
    static let pageSize = 30

    private(set) var state: LoadState = .loading
    private(set) var templates: [ProcedureTemplateSummary]
    private(set) var history: [ProcedureEventSummary]
    /// True while the last page came back full, so another may follow.
    private(set) var hasMoreHistory = false
    let isAdmin: Bool

    private let repository: ProceduresRepository
    private let cache: ResponseCaching
    private let formatters: ClinicFormatters
    private let clinicID: UUID
    private var isLoadingMore = false

    init(
        repository: ProceduresRepository,
        cache: ResponseCaching,
        formatters: ClinicFormatters,
        clinicID: UUID,
        isAdmin: Bool
    ) {
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.clinicID = clinicID
        self.isAdmin = isAdmin
        templates = cache.load([ProcedureTemplateSummary].self, for: Self.cacheKey("templates", clinicID)) ?? []
        history = cache.load([ProcedureEventSummary].self, for: Self.cacheKey("history", clinicID)) ?? []
    }

    private static func cacheKey(_ method: String, _ clinicID: UUID) -> CacheKey {
        CacheKey(method: "ProceduresRepository.\(method)", clinicID: clinicID)
    }

    /// The templates and the first page of history, side by side.
    func load() async {
        do {
            async let freshTemplates = repository.templates(clinicID: clinicID)
            async let firstPage = repository.history(clinicID: clinicID, after: nil, limit: Self.pageSize)
            let (loadedTemplates, page) = try await (freshTemplates, firstPage)
            templates = loadedTemplates
            history = page
            hasMoreHistory = page.count == Self.pageSize
            cache.store(loadedTemplates, for: Self.cacheKey("templates", clinicID))
            cache.store(page, for: Self.cacheKey("history", clinicID))
            state = .loaded
        } catch {
            let appError = AppError(error)
            // The last answer stays on screen; the banner says why it may be stale.
            state = templates.isEmpty && history.isEmpty ? .failed(appError) : .loaded
        }
    }

    /// The next page, when the last row shows. A failure keeps what is listed; the next appearance tries again.
    func loadMoreHistory() async {
        guard hasMoreHistory, !isLoadingMore, let last = history.last else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await repository.history(clinicID: clinicID, after: last, limit: Self.pageSize)
            let listed = Set(history.map(\.id))
            history += page.filter { !listed.contains($0.id) }
            hasMoreHistory = page.count == Self.pageSize
        } catch {
            // What is listed stays; the next appearance of the last row tries again.
        }
    }

    /// Nothing to list yet, once there is an answer to show.
    var hasNoTemplates: Bool { templates.isEmpty && state == .loaded }

    /// "1 not available" (danger) before "2 will run out" (warning); nil when everything is covered.
    func shortage(for template: ProcedureTemplateSummary) -> Shortage? {
        if template.notAvailableCount > 0 {
            return Shortage(text: "\(template.notAvailableCount) not available", tone: .danger)
        }
        if template.runOutCount > 0 {
            return Shortage(text: "\(template.runOutCount) will run out", tone: .warning)
        }
        return nil
    }

    /// "12 items", "1 item".
    func itemsText(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count) items"
    }

    /// "Oct 1 · 3:14 PM · Sarah", or "Cancelled · Oct 1 · 3:14 PM · Sarah"; without a name when the person left.
    func historyLine(for event: ProcedureEventSummary) -> String {
        let firstName = PersonName.first(of: event.startedByName)
        let parts = [event.cancelledAt == nil ? nil : "Cancelled", formatters.dateTime(event.startedAt), firstName]
        return parts.compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")
    }

    /// The note under the templates (f11, f12): what Start does, and who edits the templates.
    var note: String {
        isAdmin
            ? "Starting a procedure deducts its supplies right away. Pencil edits the default supplies. "
                + "Starter quantities are templates, not clinical recommendations."
            : "Starting a procedure deducts its supplies right away. Only an admin can add or edit procedure templates."
    }
}
