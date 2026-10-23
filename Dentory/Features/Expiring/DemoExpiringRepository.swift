import Foundation

/// Expiring soon without a server: f27's two batches, Bonding agent lot BA7 and Septocaine lot B441, $82 and $104
/// at risk. Disposals and their Undo are remembered in memory, so the list moves the way the server's would.
final class DemoExpiringRepository: ExpiringRepository, @unchecked Sendable {
    private var batches = ExpiringBatch.demo
    /// What each disposal took, so Undo can put it back.
    private var disposals: [UUID: (batch: ExpiringBatch, quantity: Decimal)] = [:]
    private let lock = NSLock()

    /// The batches with stock, as Home's demo figures read them.
    var currentBatches: [ExpiringBatch] {
        lock.withLock { batches.filter { $0.quantity > 0 } }
    }

    func batches(clinicID: UUID) async throws -> ExpiringList {
        try await Task.sleep(for: .milliseconds(200))
        return ExpiringList(window: 90, batches: currentBatches)
    }

    func dispose(batchID: UUID, quantity: Decimal) async throws -> WriteOutcome {
        try await Task.sleep(for: .milliseconds(300))
        let actionID = UUID()
        try lock.withLock {
            guard let index = batches.firstIndex(where: { $0.id == batchID }) else { throw AppError.notFound }
            guard quantity > 0, quantity <= batches[index].quantity else {
                throw AppError.validation(
                    field: nil, message: "The disposed quantity must be between 0 and what the batch holds."
                )
            }
            disposals[actionID] = (batches[index], quantity)
            batches[index] = batches[index].disposing(quantity)
        }
        return .applied(actionID: actionID)
    }

    func undoDisposal(actionID: UUID) async throws {
        try await Task.sleep(for: .milliseconds(200))
        lock.withLock {
            guard let disposal = disposals.removeValue(forKey: actionID),
                  let index = batches.firstIndex(where: { $0.id == disposal.batch.id })
            else { return }
            batches[index] = disposal.batch
        }
    }
}

extension ExpiringBatch {
    /// f27: Bonding agent's unopened bottle in lot BA7 expiring in November, Septocaine's lot B441 in December,
    /// as the demo seed leaves them (`supabase/seed-demo.sql`), counted from the frames' October 2.
    nonisolated static let demo: [ExpiringBatch] = [
        ExpiringBatch(
            id: demoID(0x601), productID: demoID(0xd4), name: "Bonding agent", unit: "bottles", tracking: .multiUse,
            quantity: 1, lot: "BA7", expiryMonth: CalendarDay(year: 2026, month: 11, day: 1), value: 82
        ),
        ExpiringBatch(
            id: demoID(0x602), productID: demoID(0xd1), name: "Septocaine 4% 1:100,000", unit: "cartridges",
            tracking: .countable, quantity: 34, lot: "B441", expiryMonth: CalendarDay(year: 2026, month: 12, day: 1),
            value: Decimal(string: "104.04") ?? 104
        )
    ]

    private nonisolated static func demoID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012x", number)) ?? UUID()
    }
}
