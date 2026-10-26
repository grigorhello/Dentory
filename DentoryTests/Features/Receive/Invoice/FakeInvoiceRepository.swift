import Foundation
@testable import Dentory

/// Review invoice's server: answers the readings it is given in turn, settles lines as the line functions do (the
/// states a choice may leave, the server's sentences), receives the invoice as told (MS-131), records every call, and
/// fails the way `SupabaseInvoiceRepository` does when told to.
final class FakeInvoiceRepository: InvoiceRepository, @unchecked Sendable {
    enum Call: Equatable {
        case upload(UUID, pages: Int)
        case create(UUID)
        case startReading(UUID)
        case invoice(UUID)
        case discard(UUID)
        case match(UUID, product: UUID)
        case createLine(UUID, product: UUID)
        case skip(UUID)
        case reopen(UUID)
        case batch(UUID, lot: String?, expiry: CalendarDay?)
        case confirm(UUID)
        case undoConfirm(UUID)
    }

    /// The action a confirmation applied answers.
    static let actionID = UUID(uuidString: "00000000-0000-4000-8000-000000000a01") ?? UUID()

    private let lock = NSLock()
    private var recorded: [Call] = []
    /// What `invoice(id:)` answers, one after another; the last one stays.
    var readings: [Result<InvoiceSummary, Error>] = []
    var uploadError: Error?
    var createError: Error?
    var startError: Error?
    var discardError: Error?
    /// The lines the line functions settle, as the server keeps them.
    var lines: [InvoiceLine] = []
    /// Thrown by the next line function calls, one after another.
    var lineErrors: [Error] = []
    /// Runs inside `upload`, before it answers: a test can leave the screen or tap something mid-upload there.
    var duringUpload: (@Sendable () async -> Void)?
    /// Runs inside `create`, before it answers.
    var duringCreate: (@Sendable () async -> Void)?
    /// Runs inside a line function, before it answers.
    var duringLine: (@Sendable () async -> Void)?
    /// What `confirm` answers: applied with `actionID`, queued offline, or a refusal.
    var confirmOutcome: Result<WriteOutcome, Error> = .success(.applied(actionID: FakeInvoiceRepository.actionID))
    /// Runs inside `confirm`, before it answers.
    var duringConfirm: (@Sendable () async -> Void)?
    var undoError: Error?

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
        await duringCreate?()
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

    func discard(invoiceID: UUID, clinicID: UUID) async throws {
        record(.discard(invoiceID))
        if let discardError { throw discardError }
    }

    // MARK: - Receiving

    func confirm(invoiceID: UUID) async throws -> WriteOutcome {
        record(.confirm(invoiceID))
        await duringConfirm?()
        return try confirmOutcome.get()
    }

    func undoConfirm(actionID: UUID) async throws {
        record(.undoConfirm(actionID))
        if let undoError { throw undoError }
    }

    // MARK: - Lines

    /// A line read as Matched takes the product in place of the one it is on (the decision on #101).
    func matchLine(_ lineID: UUID, to productID: UUID) async throws -> InvoiceLine {
        record(.match(lineID, product: productID))
        return try await settle(lineID, from: [.possibleMatch, .newProduct, .needsReview], orReadMatched: true) {
            $0.with(.matched, product: productID, name: Self.name(of: productID))
        }
    }

    func createLine(_ lineID: UUID, as productID: UUID) async throws -> InvoiceLine {
        record(.createLine(lineID, product: productID))
        return try await settle(lineID, from: [.possibleMatch, .newProduct]) {
            $0.with(.created, product: productID, name: $0.suggestedName)
        }
    }

    func skipLine(_ lineID: UUID) async throws -> InvoiceLine {
        record(.skip(lineID))
        return try await settle(lineID, from: [.needsReview]) { $0.with(.skipped, product: nil, name: nil) }
    }

    /// Back to the state it was read in and to the product a line read as Matched was read as.
    func reopenLine(_ lineID: UUID) async throws -> InvoiceLine {
        record(.reopen(lineID))
        return try await settle(lineID, from: nil) { line in
            guard line.state != line.readState || line.productID != line.readProductID else { return line }
            return line.with(line.readState, product: line.readProductID, name: line.readProductID.map(Self.name))
        }
    }

    /// A product's name, as `ReceivableProduct.samples` has it.
    private static func name(of productID: UUID) -> String {
        ReceivableProduct.samples.first { $0.id == productID }?.name ?? "Product \(productID.uuidString.prefix(4))"
    }

    func setBatch(of lineID: UUID, lot: String?, expiryMonth: CalendarDay?) async throws -> InvoiceLine {
        record(.batch(lineID, lot: lot, expiry: expiryMonth))
        return try await settle(lineID, from: nil) { line in
            var line = line
            line.lot = lot
            line.expiryMonth = expiryMonth
            return line
        }
    }

    private func settle(
        _ lineID: UUID, from states: Set<InvoiceLine.State>?, orReadMatched: Bool = false,
        change: (InvoiceLine) -> InvoiceLine
    ) async throws -> InvoiceLine {
        await duringLine?()
        // A request the app cancelled fails, as URLSession fails it.
        try Task.checkCancellation()
        return try lock.withLock {
            if !lineErrors.isEmpty { throw lineErrors.removeFirst() }
            guard let index = lines.firstIndex(where: { $0.id == lineID }) else { throw AppError.forbidden }
            let readMatched = orReadMatched && lines[index].state == .matched && lines[index].readState == .matched
            if let states, !states.contains(lines[index].state), !readMatched {
                throw AppError.validation(field: nil, message: "This line is already resolved.")
            }
            lines[index] = change(lines[index])
            return lines[index]
        }
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
        currency: String? = nil, lines: Int = 4, with invoiceLines: [InvoiceLine] = []
    ) -> InvoiceSummary {
        InvoiceSummary(
            id: id, status: .ready, supplier: supplier, number: number, total: total, currency: currency,
            readingStarted: true, lineCount: lines, lines: invoiceLines
        )
    }

    static func ended(_ id: UUID, _ status: Status) -> InvoiceSummary {
        InvoiceSummary(
            id: id, status: status, supplier: nil, number: nil, total: nil, currency: nil, readingStarted: true,
            lineCount: 0
        )
    }
}

extension InvoiceLine {
    /// f23's lines: SEPTO matched to Septocaine, the endo kit a Possible match, Temp-Bond a New product and the
    /// surcharge a fee.
    static let septo = line(
        1, "SEPTO 4% 1:100K 50/BX", qty: 5, unit: "boxes", price: Decimal(string: "49.80"), .matched,
        product: ReceivableProduct.septocaine
    )
    static let endoKit = line(
        2, "ENDO FILE KIT 15-40 21MM", qty: 4, unit: "boxes", price: 45, .possibleMatch,
        suggestion: ReceivableProduct.endoKit, suggestedName: "Endo file kit 15-40 21MM", suggestedUnit: "boxes"
    )
    static let tempBond = line(
        3, "TEMPBOND NE 1PK", qty: 1, unit: "pack", price: Decimal(string: "26.40"), .newProduct,
        suggestedName: "Tempbond NE", suggestedUnit: "packs"
    )
    static let surcharge = line(
        4, "HANDLING / FUEL SURCHARGE", qty: 1, unit: nil, price: Decimal(string: "4.80"), .needsReview, kind: .fee
    )
    static let frames: [InvoiceLine] = [septo, endoKit, tempBond, surcharge]

    // swiftlint:disable:next function_parameter_count
    static func line(
        _ number: Int, _ raw: String, qty: Decimal?, unit: String?, price: Decimal?, _ state: State,
        kind: Kind = .product, product: ReceivableProduct? = nil, suggestion: ReceivableProduct? = nil,
        suggestedName: String? = nil, suggestedUnit: String? = nil
    ) -> InvoiceLine {
        InvoiceLine(
            id: UUID(uuidString: String(format: "00000000-0000-4000-8000-000000000%03x", 0x410 + number)) ?? UUID(),
            number: number, raw: raw, qty: qty, unit: unit, unitPrice: price,
            lineTotal: price.flatMap { price in qty.map { $0 * price } }, kind: kind, state: state, readState: state,
            readProductID: state == .matched ? product?.id : nil, productID: product?.id, productName: product?.name,
            suggestedProductID: suggestion?.id, suggestedProductName: suggestion?.name, suggestedName: suggestedName,
            suggestedUnit: suggestedUnit, lot: nil, expiryMonth: nil
        )
    }

    /// The line in another state, as a product or none, as the line functions answer it.
    func with(_ state: State, product: UUID?, name: String?) -> InvoiceLine {
        InvoiceLine(
            id: id, number: number, raw: raw, qty: qty, unit: unit, unitPrice: unitPrice, lineTotal: lineTotal,
            kind: kind, state: state, readState: readState, readProductID: readProductID, productID: product,
            productName: name, suggestedProductID: suggestedProductID, suggestedProductName: suggestedProductName,
            suggestedName: suggestedName, suggestedUnit: suggestedUnit, lot: lot, expiryMonth: expiryMonth
        )
    }
}
