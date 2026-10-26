import Foundation

/// Review invoice without a server (previews, UI tests, screenshots): the demo clinic's Patterson invoice, read at
/// 8:55 AM with f23's four lines; with `-demoInvoice reading` an invoice being read that stays so, and with
/// `-demoInvoice failed` one whose reading fails once it is asked about (Receive delivery lists it,
/// `ReceiveOverview.demo`). Captured pages upload in a moment and are read 1.5 seconds after they are asked for, as the
/// prototype's 1.4, into the frames' invoice. Lines are settled as the server settles them (MS-130), against the shared
/// demo products, and stay so for the launch; Confirm & receive adds the delivery to those products and its Undo puts
/// them back (MS-131).
final class DemoInvoiceRepository: InvoiceRepository, @unchecked Sendable {
    /// What `-demoInvoice` asks for.
    enum Launched: String {
        case reading, failed

        static var current: Launched? {
            UserDefaults.standard.string(forKey: "demoInvoice").flatMap(Self.init(rawValue:))
        }
    }

    /// The Patterson invoice of `supabase/seed-demo.sql`, ready to review, uploaded at 8:55 AM on the frames' day.
    static let readyID = demoID(0x401)
    static let readyUploadedAt = Date(timeIntervalSince1970: 1_790_945_700)
    /// Who receives the demo's deliveries: its admin.
    static let receivedBy = "Sarah Mitchell"
    /// The invoice `-demoInvoice` adds.
    static let readingID = demoID(0x402)
    static let readingTime: TimeInterval = 1.5

    private let lock = NSLock()
    private var invoices: [UUID: InvoiceSummary]
    private var requestedAt: [UUID: Date] = [:]
    private var discardedIDs: [UUID] = []
    /// The deliveries received in this launch, by their action: the products as they were, for Undo.
    private var receipts: [UUID: (invoiceID: UUID, before: [ProductSummary])] = [:]
    private let launched: Launched?
    /// Names the products lines are matched to or created as; the frames' products without it.
    private let store: DemoProductStore?

    init(launched: Launched? = .current, store: DemoProductStore? = nil) {
        self.launched = launched
        self.store = store
        var invoices = [Self.readyID: Self.read(id: Self.readyID)]
        if launched != nil {
            invoices[Self.readingID] = Self.reading(id: Self.readingID, started: true)
        }
        self.invoices = invoices
    }

    /// The invoices set aside, newest last.
    var discarded: [UUID] { lock.withLock { discardedIDs } }

    /// The invoices set aside or received in this launch, which Receive delivery no longer lists.
    var settled: [UUID] {
        lock.withLock { discardedIDs + invoices.values.filter { $0.status == .confirmed }.map(\.id) }
    }

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

    /// A received invoice is refused, as `invoice_discard` refuses it (MS-131).
    func discard(invoiceID: UUID, clinicID: UUID) async throws {
        try await Task.sleep(for: .milliseconds(200))
        try lock.withLock {
            if invoices[invoiceID]?.status == .confirmed {
                throw AppError.refusal(Self.receivedRefusal)
            }
            discardedIDs.append(invoiceID)
            guard let invoice = invoices[invoiceID] else { return }
            invoices[invoiceID] = Self.invoice(invoice, status: .discarded)
        }
    }

    // MARK: - Receiving (MS-131)

    /// Confirm & receive as `invoice_confirm` does it, in short: every Matched or Created line with a quantity goes
    /// into the shared demo products in counted units (a pack counts its size unless the line counts the product's own
    /// unit).
    func confirm(invoiceID: UUID) async throws -> WriteOutcome {
        try await Task.sleep(for: .milliseconds(300))
        return try lock.withLock {
            guard let invoice = invoices[invoiceID] else { throw AppError.forbidden }
            guard invoice.status == .ready else {
                let refusal = invoice.status == .confirmed ? Self.receivedRefusal : Self.closedRefusal
                throw AppError.refusal(refusal)
            }
            guard invoice.lines.allSatisfy(\.isResolved) else {
                throw AppError.refusal("Resolve every line to continue.")
            }
            let lines = invoice.lines.filter(\.receivesStock)
            let received = Set(lines.compactMap(\.productID))
            let actionID = UUID()
            receipts[actionID] = (invoiceID, (store?.products ?? []).filter { received.contains($0.id) })
            for line in lines {
                guard let productID = line.productID, let qty = line.qty else { continue }
                let counted = qty * Decimal(countedPerUnit(line, productID: productID))
                _ = store?.receive(counted, of: productID, dated: line.expiryMonth != nil)
            }
            invoices[invoiceID] = Self.invoice(invoice, status: .confirmed, receivedAt: Session.demoNow)
            return .applied(actionID: actionID)
        }
    }

    /// Undo: the products are as they were before the delivery, and the invoice waits for review again.
    func undoConfirm(actionID: UUID) async throws {
        try await Task.sleep(for: .milliseconds(200))
        try lock.withLock {
            guard let receipt = receipts.removeValue(forKey: actionID), let invoice = invoices[receipt.invoiceID] else {
                throw AppError.refusal("already undone")
            }
            store?.restore(receipt.before)
            invoices[receipt.invoiceID] = Self.invoice(invoice, status: .ready)
        }
    }

    private func countedPerUnit(_ line: InvoiceLine, productID: UUID) -> Int {
        guard let pack = store?.pack(of: productID), let unit = store?.summary(id: productID)?.unit else { return 1 }
        let lineUnit = line.unit.map(ClinicFormatters.singular(of:))?.lowercased()
        return lineUnit == ClinicFormatters.singular(of: unit).lowercased() ? 1 : pack.size
    }

    // MARK: - Lines

    /// A line read as Matched takes the product picked in place of the one it is on (the decision on #101).
    func matchLine(_ lineID: UUID, to productID: UUID) async throws -> InvoiceLine {
        try await settle(lineID, from: [.possibleMatch, .newProduct, .needsReview], orReadAs: .matched) { line in
            line.settled(.matched, productID: productID, productName: productName(productID))
        }
    }

    func createLine(_ lineID: UUID, as productID: UUID) async throws -> InvoiceLine {
        try await settle(lineID, from: [.possibleMatch, .newProduct]) { line in
            line.settled(.created, productID: productID, productName: productName(productID))
        }
    }

    func skipLine(_ lineID: UUID) async throws -> InvoiceLine {
        try await settle(lineID, from: [.needsReview]) { line in
            line.settled(.skipped, productID: nil, productName: nil)
        }
    }

    /// Back to the state it was read in and the product it was read as (none but for a line read as Matched).
    func reopenLine(_ lineID: UUID) async throws -> InvoiceLine {
        try await settle(lineID, from: nil) { line in
            guard line.state != line.readState || line.productID != line.readProductID else { return line }
            return line.settled(
                line.readState, productID: line.readProductID, productName: line.readProductID.flatMap(productName)
            )
        }
    }

    func setBatch(of lineID: UUID, lot: String?, expiryMonth: CalendarDay?) async throws -> InvoiceLine {
        try await settle(lineID, from: nil) { line in
            var line = line
            let trimmed = lot?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            line.lot = trimmed.isEmpty ? nil : trimmed
            line.expiryMonth = expiryMonth
            return line
        }
    }

    /// Changes one line of an invoice waiting for review, as the line functions do: `from` the states it may leave
    /// (nil for any), and a line still in the state it was read in when that is `readState`; a resolved line is refused
    /// with the server's sentence.
    private func settle(
        _ lineID: UUID, from states: Set<InvoiceLine.State>?, orReadAs readState: InvoiceLine.State? = nil,
        change: (InvoiceLine) -> InvoiceLine
    ) async throws -> InvoiceLine {
        try await Task.sleep(for: .milliseconds(150))
        return try lock.withLock {
            guard let invoice = invoices.values.first(where: { $0.lines.contains { $0.id == lineID } }),
                  let index = invoice.lines.firstIndex(where: { $0.id == lineID })
            else { throw AppError.forbidden }
            guard invoice.status == .ready else { throw AppError.refusal(Self.closedRefusal) }
            let line = invoice.lines[index]
            let asRead = readState != nil && line.state == readState && line.readState == readState
            if let states, !states.contains(line.state), !asRead {
                throw AppError.refusal(line.isResolved ? Self.resolvedRefusal : Self.wrongWayRefusal)
            }
            var updated = invoice
            updated.lines[index] = change(line)
            invoices[invoice.id] = updated
            return updated.lines[index]
        }
    }

    private static let resolvedRefusal = "This line is already resolved."
    private static let wrongWayRefusal = "This line cannot be resolved that way."
    private static let closedRefusal = "This invoice is no longer waiting for review."
    private static let receivedRefusal = "This delivery was already received"

    private func productName(_ id: UUID) -> String? {
        store?.summary(id: id)?.name ?? ProductSummary.demo.first { $0.id == id }?.name
    }

    // MARK: - The demo invoices

    private static func reading(id: UUID, started: Bool) -> InvoiceSummary {
        InvoiceSummary(
            id: id, status: .reading, supplier: nil, number: nil, total: nil, currency: nil, readingStarted: started,
            lineCount: 0
        )
    }

    /// The frames' invoice (f23): Patterson, INV-10092, $449.00 and four lines, as `supabase/seed-demo.sql` has them.
    private static func read(id: UUID) -> InvoiceSummary {
        let lines = InvoiceLine.demo(numbered: id == readyID ? { demoID(0x410 + $0) } : { _ in UUID() })
        return InvoiceSummary(
            id: id, status: .ready, supplier: "Patterson", number: "INV-10092", total: 449, currency: nil,
            readingStarted: true, lineCount: lines.count, lines: lines,
            createdAt: id == readyID ? readyUploadedAt : .now
        )
    }

    /// The invoice in another status: set aside, received by the demo's admin at `receivedAt`, or back in review.
    private static func invoice(
        _ invoice: InvoiceSummary, status: InvoiceSummary.Status, receivedAt: Date? = nil
    ) -> InvoiceSummary {
        InvoiceSummary(
            id: invoice.id, status: status, supplier: invoice.supplier, number: invoice.number, total: invoice.total,
            currency: invoice.currency, readingStarted: invoice.readingStarted, lineCount: invoice.lineCount,
            lines: invoice.lines, createdAt: invoice.createdAt, confirmedAt: receivedAt,
            confirmedByName: receivedAt == nil ? nil : receivedBy
        )
    }

    private static func failed(id: UUID) -> InvoiceSummary {
        InvoiceSummary(
            id: id, status: .failed, supplier: nil, number: nil, total: nil, currency: nil, readingStarted: true,
            lineCount: 0
        )
    }

    /// The demo ids, numbered as `ReceiveOverview.demo` numbers the invoice to continue.
    static func demoID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-000000000%03x", number)) ?? UUID()
    }
}
