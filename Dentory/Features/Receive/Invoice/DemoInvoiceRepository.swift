import Foundation

/// Review invoice without a server (previews, UI tests, screenshots): the demo clinic's Patterson invoice, read at
/// 8:55 AM with f23's four lines; with `-demoInvoice reading` an invoice being read that stays so, and with
/// `-demoInvoice failed` one whose reading fails once it is asked about (Receive delivery lists it,
/// `ReceiveOverview.demo`). Captured pages upload in a moment and are read 1.5 seconds after they are asked for, as the
/// prototype's 1.4, into the frames' invoice. Lines are settled as the server settles them (MS-130), against the shared
/// demo products, and stay so for the launch.
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

    func discard(invoiceID: UUID, clinicID: UUID) async throws {
        try await Task.sleep(for: .milliseconds(200))
        lock.withLock {
            discardedIDs.append(invoiceID)
            guard let invoice = invoices[invoiceID], invoice.status != .confirmed else { return }
            invoices[invoiceID] = InvoiceSummary(
                id: invoiceID, status: .discarded, supplier: invoice.supplier, number: invoice.number,
                total: invoice.total, currency: invoice.currency, readingStarted: invoice.readingStarted,
                lineCount: invoice.lineCount, lines: invoice.lines
            )
        }
    }

    // MARK: - Lines

    func matchLine(_ lineID: UUID, to productID: UUID) async throws -> InvoiceLine {
        try await settle(lineID, from: [.possibleMatch, .newProduct, .needsReview]) { line in
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

    func reopenLine(_ lineID: UUID) async throws -> InvoiceLine {
        try await settle(lineID, from: nil) { line in
            guard line.state != line.readState else { return line }
            return line.readState == .matched
                ? line.settled(.matched, productID: line.productID, productName: line.productName)
                : line.settled(line.readState, productID: nil, productName: nil)
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
    /// (nil for any), refusing a resolved line with the server's sentence.
    private func settle(
        _ lineID: UUID, from states: Set<InvoiceLine.State>?, change: (InvoiceLine) -> InvoiceLine
    ) async throws -> InvoiceLine {
        try await Task.sleep(for: .milliseconds(150))
        return try lock.withLock {
            guard let invoice = invoices.values.first(where: { $0.lines.contains { $0.id == lineID } }),
                  let index = invoice.lines.firstIndex(where: { $0.id == lineID })
            else { throw AppError.forbidden }
            guard invoice.status == .ready else {
                throw AppError.validation(field: nil, message: "This invoice is no longer waiting for review.")
            }
            let line = invoice.lines[index]
            if let states, !states.contains(line.state) {
                throw AppError.validation(
                    field: nil,
                    message: line.isResolved ? Self.resolvedRefusal : "This line cannot be resolved that way."
                )
            }
            var updated = invoice
            updated.lines[index] = change(line)
            invoices[invoice.id] = updated
            return updated.lines[index]
        }
    }

    private static let resolvedRefusal = "This line is already resolved."

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
            readingStarted: true, lineCount: lines.count, lines: lines
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

private extension InvoiceLine {
    /// f23's lines: SEPTO matched to Septocaine through Patterson's alias, the endo kit a Possible match, Temp-Bond a
    /// New product and the surcharge a fee; `id(n)` names the nth.
    static func demo(numbered id: (Int) -> UUID) -> [InvoiceLine] {
        let septocaine = ProductSummary.demo[0]
        let endoKit = ProductSummary.demo[1]
        return [
            InvoiceLine(
                id: id(1), number: 1, raw: "SEPTO 4% 1:100K 50/BX", qty: 5, unit: "boxes", unitPrice: 49.8,
                lineTotal: 249, kind: .product, state: .matched, readState: .matched, productID: septocaine.id,
                productName: septocaine.name, suggestedProductID: nil, suggestedProductName: nil,
                suggestedName: "Septo 4% 1:100K", suggestedUnit: "boxes", lot: nil, expiryMonth: nil
            ),
            InvoiceLine(
                id: id(2), number: 2, raw: "ENDO FILE KIT 15-40 21MM", qty: 4, unit: "boxes", unitPrice: 45,
                lineTotal: 180, kind: .product, state: .possibleMatch, readState: .possibleMatch, productID: nil,
                productName: nil, suggestedProductID: endoKit.id, suggestedProductName: endoKit.name,
                suggestedName: "Endo file kit 15-40 21MM", suggestedUnit: "boxes", lot: nil, expiryMonth: nil
            ),
            InvoiceLine(
                id: id(3), number: 3, raw: "TEMPBOND NE 1PK", qty: 1, unit: "pack", unitPrice: 26.4, lineTotal: 26.4,
                kind: .product, state: .newProduct, readState: .newProduct, productID: nil, productName: nil,
                suggestedProductID: nil, suggestedProductName: nil, suggestedName: "Tempbond NE",
                suggestedUnit: "packs", lot: nil, expiryMonth: nil
            ),
            InvoiceLine(
                id: id(4), number: 4, raw: "HANDLING / FUEL SURCHARGE", qty: 1, unit: nil, unitPrice: 4.8,
                lineTotal: 4.8, kind: .fee, state: .needsReview, readState: .needsReview, productID: nil,
                productName: nil, suggestedProductID: nil, suggestedProductName: nil,
                suggestedName: "Handling / fuel surcharge", suggestedUnit: "units", lot: nil, expiryMonth: nil
            )
        ]
    }

    /// The line in another state, as a product or none.
    func settled(_ state: State, productID: UUID?, productName: String?) -> InvoiceLine {
        InvoiceLine(
            id: id, number: number, raw: raw, qty: qty, unit: unit, unitPrice: unitPrice, lineTotal: lineTotal,
            kind: kind, state: state, readState: readState, productID: productID, productName: productName,
            suggestedProductID: suggestedProductID, suggestedProductName: suggestedProductName,
            suggestedName: suggestedName, suggestedUnit: suggestedUnit, lot: lot, expiryMonth: expiryMonth
        )
    }
}
