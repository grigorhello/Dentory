import Foundation

/// Receive delivery without a server: the demo clinic as `supabase/seed-demo.sql` leaves it on the frames' October 2,
/// the Patterson invoice read at 8:55 AM and waiting for review, and the five lines To buy marked ordered on Oct 1;
/// with `-demoInvoice reading` an invoice being read above it, and with `-demoInvoice failed` one whose reading failed
/// (`DemoInvoiceRepository`). An invoice the demo set aside (Receive manually instead, Discard invoice, and Try again
/// or Receive manually after a failed reading) or received (Confirm & receive, or `-demoInvoice received`) is no longer
/// listed.
struct DemoReceiveRepository: ReceiveRepository {
    var now = Session.demoNow
    /// The invoice `-demoInvoice` adds above the Patterson one: being read, or one whose reading failed.
    var added = DemoInvoiceRepository.Launched.current?.added
    /// The invoices set aside or received in this launch.
    var settled: (@MainActor @Sendable () -> [UUID])?

    func overview(clinicID: UUID) async throws -> ReceiveOverview {
        try await Task.sleep(for: .milliseconds(200))
        let overview = ReceiveOverview.demo(now: now, added: added)
        let gone = Set(settled?() ?? [])
        return ReceiveOverview(invoices: overview.invoices.filter { !gone.contains($0.id) }, waiting: overview.waiting)
    }
}

extension ReceiveOverview {
    /// The demo clinic at `now` (Thursday, October 2 in the frames): the lines were ordered the day before, as To buy's
    /// demo has them, and the invoice was read at 8:55 AM in New York, a fixed time like the demo alerts'. The invoice
    /// `added` asks for, uploaded a minute before `now`, comes first: being read, or failed half a minute later.
    nonisolated static func demo(now: Date, added: PendingInvoice.Status? = nil) -> ReceiveOverview {
        let orderedAt = now.addingTimeInterval(-(24 - 7) * 3_600)
        let invoice = PendingInvoice(
            id: demoID(0x401), status: .ready, supplier: "Patterson",
            createdAt: Date(timeIntervalSince1970: 1_790_945_700)
        )
        // swiftlint:disable:next large_tuple
        let lines: [(line: Int, product: Int, name: String, unit: String, supplier: String, quantity: Decimal)] = [
            (0x504, 0x208, "Gauze", "packs", "Patterson", 5),
            (0x505, 0x201, "Needle 27g short", "needles", "Patterson", 60),
            (0x506, 0x203, "Prophy angle", "angles", "Patterson", 70),
            (0x507, 0xd9, "Root canal sealer", "kits", "Henry Schein", 1),
            (0x508, 0xda, "Temporary cement", "kits", "Patterson", 1)
        ]
        let waiting = lines.map { line in
            WaitingItem(
                id: demoID(line.line), productID: demoID(line.product), name: line.name, unit: line.unit,
                supplier: line.supplier, quantity: line.quantity, orderedAt: orderedAt
            )
        }
        let addedInvoice = added.map { status in
            PendingInvoice(
                id: demoID(0x402), status: status, supplier: nil, createdAt: now - 60,
                failedAt: status == .failed ? now - 30 : nil
            )
        }
        return ReceiveOverview(invoices: [addedInvoice, invoice].compactMap { $0 }, waiting: waiting)
    }

    /// The demo ids: To buy's lines from 0x501 and products as `ProductSummary.demo` numbers them.
    private nonisolated static func demoID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-000000000%03x", number)) ?? UUID()
    }
}
