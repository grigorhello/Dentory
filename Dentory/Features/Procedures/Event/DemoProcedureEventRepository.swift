import Foundation

/// A past procedure without a server: the demo history's procedures (f11), each with its template's supplies as
/// recorded (f14's Root canal: 10 items deducted on Oct 1 at 3:14 PM by Sarah). Edits and cancellations are kept in
/// memory, so the record moves the way the server's would.
final class DemoProcedureEventRepository: ProcedureEventRepository, @unchecked Sendable {
    private var events: [UUID: ProcedureEventDetail]
    private let byName: String
    private let lock = NSLock()

    /// `byName` is who a cancellation names: the signed-in person of the demo clinic.
    init(byName: String = "Sarah Mitchell") {
        self.byName = byName
        events = Dictionary(uniqueKeysWithValues: ProcedureEventDetail.demo.map { ($0.id, $0) })
    }

    func event(id: UUID) async throws -> ProcedureEventDetail {
        try await Task.sleep(for: .milliseconds(200))
        guard let event = lock.withLock({ events[id] }) else { throw AppError.notFound }
        return event
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        try await Task.sleep(for: .milliseconds(200))
        return ProductSummary.demo + DemoSupplies.extraProducts
    }

    func editUsage(_ edit: ProcedureUsageEdit) async throws -> WriteOutcome {
        try await Task.sleep(for: .milliseconds(300))
        lock.withLock {
            guard let event = events[edit.eventID] else { return }
            let known = Dictionary(uniqueKeysWithValues: event.items.map { ($0.id, $0) })
            let products = Dictionary(
                uniqueKeysWithValues: (ProductSummary.demo + DemoSupplies.extraProducts).map { ($0.id, $0) }
            )
            let items = edit.lines.compactMap { line -> ProcedureEventDetail.Item? in
                let takenNew = edit.takeNew.contains(line.productID)
                if let item = known[line.productID] { return item.recorded(qty: line.quantity, takenNew: takenNew) }
                guard let product = products[line.productID] else { return nil }
                return ProcedureEventDetail.Item(
                    id: product.id, name: product.name, unit: product.unit, tracking: product.tracking,
                    qty: line.quantity, takenNew: takenNew, quantity: product.quantity, unopened: product.unopened,
                    openCount: product.openCount
                )
            }
            events[edit.eventID] = event.with(items: items)
        }
        return .applied(actionID: UUID())
    }

    func cancel(eventID: UUID, note: String) async throws -> WriteOutcome {
        try await Task.sleep(for: .milliseconds(300))
        lock.withLock {
            guard let event = events[eventID] else { return }
            events[eventID] = event.cancelled(at: Session.demoNow, by: byName, note: note)
        }
        return .applied(actionID: UUID())
    }
}

extension ProcedureEventDetail {
    /// The demo history (`ProcedureEventSummary.demo`), each procedure recording its template's defaults.
    nonisolated static let demo: [ProcedureEventDetail] = ProcedureEventSummary.demo.compactMap { summary in
        guard let template = ProcedureTemplateDetail.demo.first(where: { $0.name == summary.name }) else { return nil }
        return ProcedureEventDetail(
            id: summary.id, templateID: template.id, name: summary.name, startedAt: summary.startedAt,
            startedByName: summary.startedByName, cancelledAt: nil, cancelledByName: "", cancelNote: nil,
            items: template.items.map { item in
                Item(
                    id: item.id, name: item.name, unit: item.unit, tracking: item.tracking,
                    qty: item.tracking == .countable ? item.defaultQty : 0, takenNew: false, quantity: item.quantity,
                    unopened: item.unopened, openCount: item.openCount
                )
            }
        )
    }

    /// The same procedure cancelled by `name` with `note`, as `stock_procedure_cancel` leaves it.
    nonisolated func cancelled(at date: Date, by name: String, note: String) -> ProcedureEventDetail {
        ProcedureEventDetail(
            id: id, templateID: templateID, name: self.name, startedAt: startedAt, startedByName: startedByName,
            cancelledAt: date, cancelledByName: name, cancelNote: note, items: items
        )
    }
}
