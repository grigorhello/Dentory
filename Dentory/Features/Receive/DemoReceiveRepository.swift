import Foundation

/// Receive delivery without a server: the demo clinic as `supabase/seed-demo.sql` leaves it on the frames' October 2,
/// the Patterson invoice read at 8:55 AM and waiting for review, and the five lines To buy marked ordered on Oct 1;
/// with `-demoInvoice reading` or `-demoInvoice failed`, an invoice being read above it (`DemoInvoiceRepository`).
struct DemoReceiveRepository: ReceiveRepository {
    var now = Session.demoNow
    var withInvoiceBeingRead = DemoInvoiceRepository.Launched.current != nil

    func overview(clinicID: UUID) async throws -> ReceiveOverview {
        try await Task.sleep(for: .milliseconds(200))
        return .demo(now: now, withInvoiceBeingRead: withInvoiceBeingRead)
    }
}

extension ReceiveOverview {
    /// The demo clinic at `now` (Thursday, October 2 in the frames): the lines were ordered the day before, as To buy's
    /// demo has them, and the invoice was read at 8:55 AM in New York, a fixed time like the demo alerts'. An invoice
    /// being read, uploaded a minute before `now`, comes first when asked for.
    nonisolated static func demo(now: Date, withInvoiceBeingRead: Bool = false) -> ReceiveOverview {
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
        let reading = PendingInvoice(id: demoID(0x402), status: .reading, supplier: nil, createdAt: now - 60)
        return ReceiveOverview(invoices: withInvoiceBeingRead ? [reading, invoice] : [invoice], waiting: waiting)
    }

    /// The demo ids: To buy's lines from 0x501 and products as `ProductSummary.demo` numbers them.
    private nonisolated static func demoID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-000000000%03x", number)) ?? UUID()
    }
}
