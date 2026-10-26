import Foundation

/// Review invoice without a server (previews, UI tests, screenshots): the demo clinic's Patterson invoice, read at
/// 8:55 AM; with `-demoInvoice reading` an invoice being read that stays so, and with `-demoInvoice failed` one whose
/// reading fails once it is asked about (Receive delivery lists it, `ReceiveOverview.demo`). Captured pages upload in
/// a moment and are read 1.5 seconds after they are asked for, as the prototype's 1.4, into the frames' invoice.
final class DemoInvoiceRepository: InvoiceRepository, @unchecked Sendable {
    /// What `-demoInvoice` asks for.
    enum Launched: String {
        case reading, failed

        static var current: Launched? {
            UserDefaults.standard.string(forKey: "demoInvoice").flatMap(Self.init(rawValue:))
        }
    }

    /// The Patterson invoice of `supabase/seed-demo.sql`, ready to review.
    static let readyID = demoID(0x401)
    /// The invoice `-demoInvoice` adds.
    static let readingID = demoID(0x402)
    static let readingTime: TimeInterval = 1.5

    private let lock = NSLock()
    private var invoices: [UUID: InvoiceSummary]
    private var requestedAt: [UUID: Date] = [:]
    private var discardedIDs: [UUID] = []
    private let launched: Launched?

    init(launched: Launched? = .current) {
        self.launched = launched
        var invoices = [Self.readyID: Self.read(id: Self.readyID)]
        if launched != nil {
            invoices[Self.readingID] = Self.reading(id: Self.readingID, started: true)
        }
        self.invoices = invoices
    }

    /// The invoices set aside, newest last.
    var discarded: [UUID] { lock.withLock { discardedIDs } }

    func upload(_ document: InvoiceDocument, clinicID: UUID) async throws {
        try await Task.sleep(for: .milliseconds(400))
    }

    func create(_ document: InvoiceDocument, clinicID: UUID) async throws -> InvoiceSummary {
        lock.withLock {
            let invoice = invoices[document.id] ?? Self.reading(id: document.id, started: false)
            invoices[document.id] = invoice
            return invoice
        }
    }

    func startReading(invoiceID: UUID) async throws {
        lock.withLock {
            guard let invoice = invoices[invoiceID], invoice.status == .reading, !invoice.readingStarted else { return }
            invoices[invoiceID] = Self.reading(id: invoiceID, started: true)
            requestedAt[invoiceID] = Date.now
        }
    }

    func invoice(id: UUID) async throws -> InvoiceSummary {
        try await Task.sleep(for: .milliseconds(200))
        return try lock.withLock {
            guard var invoice = invoices[id] else { throw AppError.forbidden }
            if id == Self.readingID, launched == .failed, invoice.status == .reading {
                invoice = Self.failed(id: id)
            } else if let requested = requestedAt[id], Date.now.timeIntervalSince(requested) >= Self.readingTime {
                invoice = Self.read(id: id)
                requestedAt[id] = nil
            }
            invoices[id] = invoice
            return invoice
        }
    }

    func discard(invoiceID: UUID) async throws {
        lock.withLock {
            discardedIDs.append(invoiceID)
            guard let invoice = invoices[invoiceID], invoice.status != .confirmed else { return }
            invoices[invoiceID] = InvoiceSummary(
                id: invoiceID, status: .discarded, supplier: invoice.supplier, number: invoice.number,
                total: invoice.total, currency: invoice.currency, readingStarted: invoice.readingStarted,
                lineCount: invoice.lineCount
            )
        }
    }

    private static func reading(id: UUID, started: Bool) -> InvoiceSummary {
        InvoiceSummary(
            id: id, status: .reading, supplier: nil, number: nil, total: nil, currency: nil, readingStarted: started,
            lineCount: 0
        )
    }

    /// The frames' invoice (f23): Patterson, INV-10092, $449.00 and four lines.
    private static func read(id: UUID) -> InvoiceSummary {
        InvoiceSummary(
            id: id, status: .ready, supplier: "Patterson", number: "INV-10092", total: 449, currency: nil,
            readingStarted: true, lineCount: 4
        )
    }

    private static func failed(id: UUID) -> InvoiceSummary {
        InvoiceSummary(
            id: id, status: .failed, supplier: nil, number: nil, total: nil, currency: nil, readingStarted: true,
            lineCount: 0
        )
    }

    /// The demo ids, numbered as `ReceiveOverview.demo` numbers the invoice to continue.
    private static func demoID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-000000000%03x", number)) ?? UUID()
    }
}
