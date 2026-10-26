import Foundation
@testable import Dentory

final class FakeManualReceiveRepository: ManualReceiveRepository, @unchecked Sendable {
    var productsResult: Result<[ReceivableProduct], Error> = .success(ReceivableProduct.samples)
    var receiveResult: Result<WriteOutcome, Error> = .success(.applied(actionID: UUID()))
    private(set) var productCalls: [UUID] = []
    private(set) var receipts: [ManualReceipt] = []

    func products(clinicID: UUID) async throws -> [ReceivableProduct] {
        productCalls.append(clinicID)
        return try productsResult.get()
    }

    func receive(_ receipt: ManualReceipt) async throws -> WriteOutcome {
        receipts.append(receipt)
        return try receiveResult.get()
    }
}

extension ReceivableProduct {
    /// Received in boxes of 50 cartridges, 54 in stock (f20).
    nonisolated static let septocaine = sample(
        0x201, "Septocaine 4% 1:100,000", "Anesthetic", "cartridges", pack: ("box", 50), 54
    )
    /// Received by the kit, 1 in stock.
    nonisolated static let endoKit = sample(0x202, "Endo file kit #15-40", "Endodontics", "kits", 1)
    /// Multi-use, received by the kit: none unopened, one open.
    nonisolated static let sealer = sample(
        0x217, "Root canal sealer", "Endodontics", "kits", tracking: .multiUse, 0, open: 1
    )
    /// Multi-use, received in boxes of 10 syringes: 2 unopened, one open.
    nonisolated static let composite = sample(
        0x203, "Composite A2", "Restorative", "syringes", pack: ("box", 10), tracking: .multiUse, 2, open: 1
    )
    /// No category.
    nonisolated static let gauze = sample(0x228, "Gauze", nil, "packs", 8)

    nonisolated static let samples: [ReceivableProduct] = [septocaine, endoKit, sealer, composite, gauze]

    private nonisolated static func sample(
        _ number: Int, _ name: String, _ category: String?, _ unit: String, pack: (String, Int)? = nil,
        tracking: TrackingMode = .countable, _ unopened: Decimal, open: Int = 0
    ) -> ReceivableProduct {
        ReceivableProduct(
            id: UUID(uuidString: String(format: "d0000000-0000-4000-8000-000000000%03x", number)) ?? UUID(),
            name: name, categoryName: category, unit: unit, packUnit: pack?.0, packSize: pack?.1, tracking: tracking,
            quantity: unopened + (tracking == .multiUse ? Decimal(open) : 0), unopened: unopened, openCount: open
        )
    }
}
