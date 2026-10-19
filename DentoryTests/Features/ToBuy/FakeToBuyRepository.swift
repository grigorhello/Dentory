import Foundation
@testable import Dentory

final class FakeToBuyRepository: ToBuyRepository, @unchecked Sendable {
    var itemsResult: Result<[ToBuyItem], Error> = .success(ToBuyItem.demo(now: Session.demoNow))
    var productsResult: Result<[ProductSummary], Error> = .success(ProductSummary.demo + DemoSupplies.extraProducts)
    var addResult: Result<AddedToBuy, Error> = .success(AddedToBuy(id: UUID(), qty: 2))
    var setQuantityError: Error?
    var removeError: Error?
    var markOrderedResult: Result<Int, Error>?
    private(set) var itemCalls = 0
    private(set) var adds: [UUID] = []
    private(set) var quantities: [(UUID, Decimal)] = []
    private(set) var removals: [UUID] = []
    private(set) var orders: [[UUID]] = []
    /// Every write in the order it reached the server.
    private(set) var log: [String] = []

    func items(clinicID: UUID) async throws -> [ToBuyItem] {
        itemCalls += 1
        return try itemsResult.get()
    }

    func products(clinicID: UUID) async throws -> [ProductSummary] {
        try productsResult.get()
    }

    func add(clinicID: UUID, productID: UUID) async throws -> AddedToBuy {
        adds.append(productID)
        log.append("add")
        return try addResult.get()
    }

    func setQuantity(itemID: UUID, quantity: Decimal) async throws {
        quantities.append((itemID, quantity))
        log.append("quantity")
        if let setQuantityError { throw setQuantityError }
    }

    func remove(itemID: UUID) async throws {
        removals.append(itemID)
        log.append("remove")
        if let removeError { throw removeError }
    }

    func markOrdered(clinicID: UUID, itemIDs: [UUID]) async throws -> Int {
        orders.append(itemIDs)
        log.append("ordered")
        return try markOrderedResult?.get() ?? itemIDs.count
    }
}
