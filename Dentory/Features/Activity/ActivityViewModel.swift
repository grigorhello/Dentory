import Foundation
import Observation

/// Activity (f8; PRD §6.8; Appendix B `activity`), opened from Home's bell: the Alerts segment with the clinic's open
/// alerts, newest first, each a sentence that opens what resolves it; History arrives with MS-134. Looking at Alerts
/// marks them seen, which clears the bell's dot. The last alerts are served from the cache while fresh ones load or
/// the network is gone (MS-108). The lines are in `ActivityViewModel+Copy.swift`.
@MainActor
@Observable
final class ActivityViewModel {
    enum LoadState: Equatable { case loading, loaded, failed(AppError) }

    nonisolated enum Segment: Hashable, Sendable {
        case alerts, history
    }

    /// What an alert opens: the product it is about, or the delivery waiting for review.
    enum Destination: Equatable {
        case product(UUID)
        case delivery
    }

    private(set) var state: LoadState = .loading
    private(set) var alerts: [ActivityAlert]
    var segment: Segment = .alerts

    let formatters: ClinicFormatters
    private let repository: ActivityRepository
    private let cache: ResponseCaching
    private let clinicID: UUID

    init(repository: ActivityRepository, cache: ResponseCaching, formatters: ClinicFormatters, clinicID: UUID) {
        self.repository = repository
        self.cache = cache
        self.formatters = formatters
        self.clinicID = clinicID
        alerts = cache.load([ActivityAlert].self, for: Self.cacheKey(clinicID)) ?? []
    }

    private static func cacheKey(_ clinicID: UUID) -> CacheKey {
        CacheKey(method: "ActivityRepository.alerts", clinicID: clinicID)
    }

    /// Reads the alerts and, once they are on screen, marks them seen. A reload that fails keeps the last ones.
    func load() async {
        do {
            let fresh = try await repository.alerts(clinicID: clinicID)
            cache.store(fresh, for: Self.cacheKey(clinicID))
            alerts = fresh
            state = .loaded
            await markSeen()
        } catch {
            state = alerts.isEmpty ? .failed(AppError(error)) : .loaded
        }
    }

    /// The bell's dot clears once the alerts are seen; a failure leaves it for the next look.
    private func markSeen() async {
        guard segment == .alerts else { return }
        try? await repository.markSeen(clinicID: clinicID)
    }

    /// Where an alert leads (PRD §5: to what resolves it): the product, or the delivery waiting for review.
    func destination(for alert: ActivityAlert) -> Destination? {
        switch alert.kind {
        case .outOfStock, .low, .expiring, .missingExpiry:
            alert.productID.map(Destination.product)
        case .invoiceReady:
            .delivery
        }
    }
}
