import Foundation
@testable import Dentory

/// Review invoice's server: answers the readings it is given in turn, records every call, and fails the way
/// `SupabaseInvoiceRepository` does when told to.
final class FakeInvoiceRepository: InvoiceRepository, @unchecked Sendable {
    enum Call: Equatable {
        case upload(UUID, pages: Int)
        case create(UUID)
        case startReading(UUID)
        case invoice(UUID)
        case discard(UUID)
    }

    private let lock = NSLock()
    private var recorded: [Call] = []
    /// What `invoice(id:)` answers, one after another; the last one stays.
    var readings: [Result<InvoiceSummary, Error>] = []
    var uploadError: Error?
    var createError: Error?
    var startError: Error?
    /// Runs inside `upload`, before it answers: a test can leave the screen or tap something mid-upload there.
    var duringUpload: (@Sendable () async -> Void)?

    var calls: [Call] { lock.withLock { recorded } }

    private func record(_ call: Call) {
        lock.withLock { recorded.append(call) }
    }

    func upload(_ document: InvoiceDocument, clinicID: UUID) async throws {
        record(.upload(document.id, pages: document.pages.count))
        await duringUpload?()
        if let uploadError { throw uploadError }
    }

    func create(_ document: InvoiceDocument, clinicID: UUID) async throws -> InvoiceSummary {
        record(.create(document.id))
        if let createError { throw createError }
        return .reading(document.id, started: false)
    }

    func startReading(invoiceID: UUID) async throws {
        record(.startReading(invoiceID))
        if let startError { throw startError }
    }

    func invoice(id: UUID) async throws -> InvoiceSummary {
        record(.invoice(id))
        let next = lock.withLock { readings.count > 1 ? readings.removeFirst() : readings.first }
        guard let next else { throw AppError.notFound }
        return try next.get()
    }

    func discard(invoiceID: UUID) async throws {
        record(.discard(invoiceID))
    }
}

extension InvoiceSummary {
    static func reading(_ id: UUID, started: Bool = true) -> InvoiceSummary {
        InvoiceSummary(
            id: id, status: .reading, supplier: nil, number: nil, total: nil, currency: nil, readingStarted: started,
            lineCount: 0
        )
    }

    static func ready(
        _ id: UUID, supplier: String? = "Patterson Dental", number: String? = "INV-10092", total: Decimal? = 449,
        currency: String? = nil, lines: Int = 4
    ) -> InvoiceSummary {
        InvoiceSummary(
            id: id, status: .ready, supplier: supplier, number: number, total: total, currency: currency,
            readingStarted: true, lineCount: lines
        )
    }

    static func ended(_ id: UUID, _ status: Status) -> InvoiceSummary {
        InvoiceSummary(
            id: id, status: status, supplier: nil, number: nil, total: nil, currency: nil, readingStarted: true,
            lineCount: 0
        )
    }
}
